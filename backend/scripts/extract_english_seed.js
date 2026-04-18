const fs = require("fs/promises");
const path = require("path");
const axios = require("axios");

const OUTPUT_DIR = path.join(__dirname, "..", "data", "seed");
const CACHE_DIR = path.join(__dirname, "..", "data", "cache");
const OUTPUT_JSON = path.join(OUTPUT_DIR, "english_1000.json");
const OUTPUT_CSV = path.join(OUTPUT_DIR, "english_1000.csv");
const DEFINITION_CACHE_FILE = path.join(CACHE_DIR, "english_seed_definition_cache.json");

const FREQ_SOURCE =
  "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_50k.txt";

function isEnglishWord(word) {
  return /^[a-z][a-z'-]*$/i.test(word);
}

function normalizeEnglishWord(word) {
  return String(word || "")
    .trim()
    .toLowerCase();
}

function normalizeDefinition(input) {
  const text = String(input || "")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return "";

  const sentence = text.split(/[.;]/)[0].trim();
  if (!sentence) return "";

  return sentence.length > 100 ? sentence.slice(0, 100).trim() : sentence;
}

const ENGLISH_MEANING_OVERRIDES = {
  you: "the person being addressed",
  i: "the speaker",
  the: "definite article",
  to: "toward; in order to",
  a: "indefinite article",
  it: "thing or situation",
  and: "used to connect words or ideas",
  that: "used to refer to something",
  of: "belonging to; relating to",
  in: "inside; within",
  is: "form of be",
  for: "intended for; because of",
  on: "on top of; about",
  with: "accompanied by",
  as: "in the role of; like",
  was: "past form of be",
  at: "in or near a place",
  by: "next to; through the action of",
  be: "to exist",
  this: "the thing near or being discussed",
  have: "to possess; to experience",
  from: "starting point",
  or: "alternative",
  one: "single unit",
  had: "past form of have",
  not: "negative marker",
  but: "however; except",
  what: "which thing",
  all: "the whole amount",
  were: "past plural form of be",
  we: "the speaker and others",
  when: "at what time",
  your: "belonging to you",
  can: "to be able to",
  said: "past form of say",
  there: "in that place",
  use: "to employ",
  each: "every one of a group",
  which: "what one; what kind",
  she: "female person previously mentioned",
  do: "to perform",
  how: "in what way",
  their: "belonging to them",
  if: "in the case that",
  will: "future marker; intention",
  up: "toward a higher place",
  other: "different or additional",
  about: "concerning; approximately",
  out: "to the outside",
  many: "a large number",
};

function parseFrequencyWords(raw, max = 20000) {
  const lines = String(raw || "").split("\n");
  const words = [];
  const seen = new Set();

  for (const line of lines) {
    const token = normalizeEnglishWord(line.trim().split(/\s+/)[0] || "");
    if (!token) continue;
    if (!isEnglishWord(token)) continue;
    if (seen.has(token)) continue;
    seen.add(token);
    words.push(token);
    if (words.length >= max) break;
  }

  return words;
}

async function loadDefinitionCache() {
  await fs.mkdir(CACHE_DIR, { recursive: true });
  try {
    const raw = await fs.readFile(DEFINITION_CACHE_FILE, "utf8");
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object") return parsed;
    return {};
  } catch (_) {
    return {};
  }
}

async function saveDefinitionCache(cache) {
  await fs.writeFile(DEFINITION_CACHE_FILE, JSON.stringify(cache, null, 2), "utf8");
}

async function fetchDefinition(word) {
  try {
    const response = await axios.get(
      `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`,
      { timeout: 12000 },
    );

    const root = Array.isArray(response.data) ? response.data[0] : null;
    const meanings = root && Array.isArray(root.meanings) ? root.meanings : [];
    for (const meaning of meanings) {
      const defs = Array.isArray(meaning.definitions) ? meaning.definitions : [];
      for (const def of defs) {
        const text = String(def.definition || "").trim();
        if (text) {
          return normalizeDefinition(text) || word;
        }
      }
    }

    return word;
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
  console.log("[english-seed] Downloading frequency list...");
  const response = await axios.get(FREQ_SOURCE, { timeout: 30000 });
  if (response.status !== 200 || !response.data) {
    throw new Error("Unable to download English frequency list.");
  }

  const frequencyWords = parseFrequencyWords(response.data, 25000);
  console.log(`[english-seed] Frequency candidates: ${frequencyWords.length}`);

  const targetWords = frequencyWords.slice(0, 1000);
  const cache = await loadDefinitionCache();
  const missing = targetWords.filter((word) => !cache[word]);

  console.log(`[english-seed] Cached definitions: ${targetWords.length - missing.length}`);
  if (missing.length > 0) {
    console.log(`[english-seed] Fetching missing definitions: ${missing.length}`);
    const translated = await mapWithConcurrency(missing, 10, async (word) => {
      const meaning = await fetchDefinition(word);
      return { word, meaning };
    });

    for (const entry of translated) {
      cache[entry.word] = entry.meaning || entry.word;
    }

    await saveDefinitionCache(cache);
  }

  const rows = targetWords.map((word, index) => {
    const override = ENGLISH_MEANING_OVERRIDES[word];
    return {
      language_code: "en",
      word,
      pinyin: "",
      meaning_en: override || normalizeDefinition(cache[word] || word) || word,
      frequency_rank: index + 1,
      source_freq: "hermitdave-frequencywords-en-50k",
      source_dict: "dictionaryapi-dev",
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

  console.log(`[english-seed] Wrote JSON: ${OUTPUT_JSON}`);
  console.log(`[english-seed] Wrote CSV: ${OUTPUT_CSV}`);
  console.log("[english-seed] Done.");
}

main().catch((error) => {
  console.error("[english-seed] Failed:", error.message);
  process.exit(1);
});
