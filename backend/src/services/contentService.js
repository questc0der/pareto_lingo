const fs = require("fs/promises");
const path = require("path");
const axios = require("axios");
const { translateWord, mapWithConcurrency } = require("./translatorService");

const LANGUAGE_MAP = {
  fr: "fr",
  es: "es",
  de: "de",
};

function getSupportedLanguages() {
  return Object.keys(LANGUAGE_MAP);
}

function normalizeLanguage(input) {
  const code = String(input || "fr").toLowerCase();
  return LANGUAGE_MAP[code] ? code : "fr";
}

async function ensureDirectory(directoryPath) {
  await fs.mkdir(directoryPath, { recursive: true });
}

async function loadCache(cacheDir, languageCode) {
  await ensureDirectory(cacheDir);
  const filePath = path.join(cacheDir, `${languageCode}.json`);

  try {
    const content = await fs.readFile(filePath, "utf8");
    const parsed = JSON.parse(content);
    if (typeof parsed === "object" && parsed !== null) {
      return { filePath, map: parsed };
    }
    return { filePath, map: {} };
  } catch (_) {
    return { filePath, map: {} };
  }
}

async function saveCache(filePath, map) {
  await fs.writeFile(filePath, JSON.stringify(map, null, 2), "utf8");
}

async function fetchTopWords(languageCode, limit) {
  const url = `https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/${languageCode}/${languageCode}_50k.txt`;
  const response = await axios.get(url, { timeout: 20000 });
  const lines = String(response.data || "").split("\n");

  const words = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const word = trimmed.split(" ")[0].trim();
    if (!word) continue;
    words.push(word);
    if (words.length >= limit) break;
  }

  return words;
}

async function getFlashcards({
  languageCode,
  limit,
  targetLanguage,
  cacheDir,
  translationConcurrency,
}) {
  const resolvedLanguage = normalizeLanguage(languageCode);
  const resolvedLimit = Math.min(Math.max(Number(limit) || 1000, 1), 1000);

  const words = await fetchTopWords(resolvedLanguage, resolvedLimit);
  const { filePath, map } = await loadCache(cacheDir, resolvedLanguage);

  const missingWords = words.filter((word) => !map[word]);

  if (missingWords.length > 0) {
    const translatedWords = await mapWithConcurrency(
      missingWords,
      translationConcurrency,
      async (word) => {
        const translated = await translateWord({
          word,
          sourceLanguage: resolvedLanguage,
          targetLanguage,
        });
        return { word, translated };
      },
    );

    for (const item of translatedWords) {
      map[item.word] = item.translated || item.word;
    }

    await saveCache(filePath, map);
  }

  return {
    language: resolvedLanguage,
    total: words.length,
    items: words.map((word) => ({
      word,
      meaning: map[word] || word,
    })),
  };
}

module.exports = {
  getFlashcards,
  getSupportedLanguages,
  normalizeLanguage,
};
