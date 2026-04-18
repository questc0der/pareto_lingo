const fs = require("fs/promises");
const path = require("path");
const zlib = require("zlib");
const axios = require("axios");

const OUTPUT_DIR = path.join(__dirname, "..", "data", "seed");
const OUTPUT_JSON = path.join(OUTPUT_DIR, "mandarin_1000.json");
const OUTPUT_CSV = path.join(OUTPUT_DIR, "mandarin_1000.csv");

const FREQ_SOURCES = [
  "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/zh_cn/zh_cn_50k.txt",
  "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/zh/zh_50k.txt",
];

const CEDICT_URL =
  "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz";

function isChineseWord(word) {
  return /^[\u3400-\u4DBF\u4E00-\u9FFF]+$/u.test(word);
}

function parseFrequencyWords(raw, max = 10000) {
  const lines = String(raw || "").split("\n");
  const words = [];
  const seen = new Set();

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const token = trimmed.split(/\s+/)[0].trim();
    if (!token) continue;
    if (!isChineseWord(token)) continue;
    if (seen.has(token)) continue;
    seen.add(token);
    words.push(token);
    if (words.length >= max) break;
  }

  return words;
}

function normalizeMeaning(gloss) {
  return gloss
    .replace(/\([^)]*\)/g, " ")
    .replace(/\s+/g, " ")
    .replace(/^to\s+/i, "")
    .replace(/\s*;\s*/g, "; ")
    .trim();
}

function parseCedictLine(line) {
  if (!line || line.startsWith("#")) return null;

  // Format: trad simp [pin yin] /meaning 1/meaning 2/
  const match = line.match(/^(\S+)\s+(\S+)\s+\[([^\]]+)\]\s+\/(.+)\/$/);
  if (!match) return null;

  const simplified = match[2].trim();
  const pinyin = match[3].trim();
  const senses = match[4]
    .split("/")
    .map((s) => s.trim())
    .filter(Boolean);

  if (!simplified || !isChineseWord(simplified) || senses.length === 0) {
    return null;
  }

  const firstMeaning = normalizeMeaning(senses[0]);
  if (!firstMeaning) return null;

  return {
    word: simplified,
    pinyin,
    meaning_en: firstMeaning,
  };
}

function escapeCsv(value) {
  const raw = String(value ?? "");
  if (raw.includes(",") || raw.includes('"') || raw.includes("\n")) {
    return `"${raw.replace(/"/g, '""')}"`;
  }
  return raw;
}

async function fetchFrequencyList() {
  for (const source of FREQ_SOURCES) {
    try {
      const response = await axios.get(source, { timeout: 30000 });
      if (response.status === 200 && response.data) {
        return parseFrequencyWords(response.data, 20000);
      }
    } catch (_) {
      // Try next source
    }
  }

  throw new Error("Unable to download Mandarin frequency list from configured sources.");
}

async function fetchCedictMap() {
  const response = await axios.get(CEDICT_URL, {
    responseType: "arraybuffer",
    timeout: 45000,
  });

  const unzipped = zlib.gunzipSync(Buffer.from(response.data));
  const text = unzipped.toString("utf8");
  const lines = text.split("\n");

  const map = new Map();
  for (const line of lines) {
    const parsed = parseCedictLine(line.trim());
    if (!parsed) continue;

    // Keep first sense for stable, deterministic output
    if (!map.has(parsed.word)) {
      map.set(parsed.word, parsed);
    }
  }

  return map;
}

async function main() {
  console.log("[mandarin-seed] Downloading frequency list...");
  const frequencyWords = await fetchFrequencyList();
  console.log(`[mandarin-seed] Frequency candidates: ${frequencyWords.length}`);

  console.log("[mandarin-seed] Downloading CC-CEDICT...");
  const cedictMap = await fetchCedictMap();
  console.log(`[mandarin-seed] CEDICT entries loaded: ${cedictMap.size}`);

  const rows = [];
  const seen = new Set();

  for (const word of frequencyWords) {
    if (rows.length >= 1000) break;
    if (seen.has(word)) continue;

    const entry = cedictMap.get(word);
    if (!entry) continue;

    seen.add(word);
    rows.push({
      language_code: "zh",
      word: entry.word,
      pinyin: entry.pinyin,
      meaning_en: entry.meaning_en,
      frequency_rank: rows.length + 1,
      source_freq: "hermitdave-frequencywords-zh_cn-50k",
      source_dict: "cc-cedict",
    });
  }

  if (rows.length < 1000) {
    throw new Error(
      `Only ${rows.length} matched words were generated; expected at least 1000.`,
    );
  }

  await fs.mkdir(OUTPUT_DIR, { recursive: true });
  await fs.writeFile(OUTPUT_JSON, JSON.stringify(rows, null, 2), "utf8");

  const header =
    "language_code,word,pinyin,meaning_en,frequency_rank,source_freq,source_dict";
  const csvLines = rows.map((row) =>
    [
      row.language_code,
      row.word,
      row.pinyin,
      row.meaning_en,
      row.frequency_rank,
      row.source_freq,
      row.source_dict,
    ]
      .map(escapeCsv)
      .join(","),
  );

  await fs.writeFile(OUTPUT_CSV, [header, ...csvLines].join("\n"), "utf8");

  console.log(`[mandarin-seed] Wrote JSON: ${OUTPUT_JSON}`);
  console.log(`[mandarin-seed] Wrote CSV: ${OUTPUT_CSV}`);
  console.log("[mandarin-seed] Done.");
}

main().catch((error) => {
  console.error("[mandarin-seed] Failed:", error.message);
  process.exit(1);
});
