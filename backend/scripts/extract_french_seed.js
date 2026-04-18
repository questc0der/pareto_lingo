const fs = require("fs/promises");
const path = require("path");
const axios = require("axios");

const OUTPUT_DIR = path.join(__dirname, "..", "data", "seed");
const CACHE_DIR = path.join(__dirname, "..", "data", "cache");
const OUTPUT_JSON = path.join(OUTPUT_DIR, "french_1000.json");
const OUTPUT_CSV = path.join(OUTPUT_DIR, "french_1000.csv");
const TRANSLATION_CACHE_FILE = path.join(CACHE_DIR, "french_seed_en_cache.json");

const FREQ_SOURCE =
  "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/fr/fr_50k.txt";

function isFrenchWord(word) {
  return /^[a-zA-ZÀ-ÖØ-öø-ÿœŒ'’-]+$/u.test(word);
}

function normalizeFrenchWord(word) {
  return String(word || "")
    .trim()
    .toLowerCase();
}

function normalizeFrenchMeaning(input) {
  const text = String(input || "")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return "";

  const compact = text.split(/[.;]/)[0].trim();
  if (!compact) return "";

  const lowered = compact.toLowerCase();
  return lowered.length > 80 ? lowered.slice(0, 80).trim() : lowered;
}

const MEANING_OVERRIDES = {
  de: "of",
  je: "i",
  est: "is",
  pas: "not",
  le: "the",
  que: "that",
  la: "the",
  et: "and",
  les: "the",
  des: "some",
  en: "in",
  un: "a",
  une: "a",
  du: "of the",
  pour: "for",
  qui: "who",
  dans: "in",
  sur: "on",
  au: "to the",
  avec: "with",
};

function parseFrequencyWords(raw, max = 20000) {
  const lines = String(raw || "").split("\n");
  const words = [];
  const seen = new Set();

  for (const line of lines) {
    const token = normalizeFrenchWord(line.trim().split(/\s+/)[0] || "");
    if (!token) continue;
    if (!isFrenchWord(token)) continue;
    if (seen.has(token)) continue;
    seen.add(token);
    words.push(token);
    if (words.length >= max) break;
  }

  return words;
}

async function loadTranslationCache() {
  await fs.mkdir(CACHE_DIR, { recursive: true });
  try {
    const raw = await fs.readFile(TRANSLATION_CACHE_FILE, "utf8");
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object") return parsed;
    return {};
  } catch (_) {
    return {};
  }
}

async function saveTranslationCache(cache) {
  await fs.writeFile(TRANSLATION_CACHE_FILE, JSON.stringify(cache, null, 2), "utf8");
}

async function translateToEnglish(word) {
  try {
    const response = await axios.get(
      "https://translate.googleapis.com/translate_a/single",
      {
        params: {
          client: "gtx",
          sl: "fr",
          tl: "en",
          dt: "t",
          q: word,
        },
        timeout: 12000,
      },
    );

    const data = response.data;
    const translated =
      Array.isArray(data) &&
      Array.isArray(data[0]) &&
      Array.isArray(data[0][0]) &&
      data[0][0][0]
        ? String(data[0][0][0]).trim()
        : "";

    return translated || word;
  } catch (_) {
    return word;
  }
}

async function mapWithConcurrency(items, concurrency, mapper) {
  const results = new Array(items.length);
  let current = 0;

  const workers = Array.from({ length: Math.max(1, concurrency) }, async () => {
    while (current < items.length) {
      const index = current;
      current += 1;
      results[index] = await mapper(items[index], index);
    }
  });

  await Promise.all(workers);
  return results;
}

function escapeCsv(value) {
  const raw = String(value ?? "");
  if (raw.includes(",") || raw.includes('"') || raw.includes("\n")) {
    return `"${raw.replace(/"/g, '""')}"`;
  }
  return raw;
}

async function main() {
  console.log("[french-seed] Downloading frequency list...");
  const response = await axios.get(FREQ_SOURCE, { timeout: 30000 });
  if (response.status !== 200 || !response.data) {
    throw new Error("Unable to download French frequency list.");
  }

  const frequencyWords = parseFrequencyWords(response.data, 25000);
  console.log(`[french-seed] Frequency candidates: ${frequencyWords.length}`);

  const targetWords = frequencyWords.slice(0, 1000);
  const cache = await loadTranslationCache();
  const missing = targetWords.filter((word) => !cache[word]);

  console.log(`[french-seed] Cached translations: ${targetWords.length - missing.length}`);
  if (missing.length > 0) {
    console.log(`[french-seed] Translating missing words: ${missing.length}`);
    const translated = await mapWithConcurrency(missing, 12, async (word) => {
      const meaning = await translateToEnglish(word);
      return { word, meaning };
    });

    for (const entry of translated) {
      cache[entry.word] = entry.meaning || entry.word;
    }

    await saveTranslationCache(cache);
  }

  const rows = targetWords.map((word, index) => {
    const overridden = MEANING_OVERRIDES[word];
    const normalizedMeaning = normalizeFrenchMeaning(cache[word] || word);
    return {
      language_code: "fr",
      word,
      pinyin: "",
      meaning_en: overridden || normalizedMeaning || word,
      frequency_rank: index + 1,
      source_freq: "hermitdave-frequencywords-fr-50k",
      source_dict: "google-translate-gtx",
    };
  });

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

  console.log(`[french-seed] Wrote JSON: ${OUTPUT_JSON}`);
  console.log(`[french-seed] Wrote CSV: ${OUTPUT_CSV}`);
  console.log("[french-seed] Done.");
}

main().catch((error) => {
  console.error("[french-seed] Failed:", error.message);
  process.exit(1);
});
