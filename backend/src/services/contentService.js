const fs = require("fs/promises");
const path = require("path");
const axios = require("axios");
const { translateWord, mapWithConcurrency } = require("./translatorService");

const LANGUAGE_MAP = {
  fr: "fr",
  en: "en",
  zh: "zh",
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

function normalizeTargetLanguage(input) {
  const value = String(input || "en")
    .toLowerCase()
    .trim();
  return value || "en";
}

function resolveMeaningFromRow(row, targetLanguage) {
  if (!row || typeof row !== "object") return "";

  const target = normalizeTargetLanguage(targetLanguage);
  const directKey = `meaning_${target}`;
  if (row[directKey] && String(row[directKey]).trim()) {
    return String(row[directKey]).trim();
  }

  if (row.meaning_en && String(row.meaning_en).trim()) {
    return String(row.meaning_en).trim();
  }

  if (row.meaning && String(row.meaning).trim()) {
    return String(row.meaning).trim();
  }

  return "";
}

async function fetchFlashcardsFromSupabase({
  languageCode,
  limit,
  targetLanguage,
  supabaseUrl,
  supabaseAnonKey,
  supabaseTable,
}) {
  const hasSupabaseConfig =
    typeof supabaseUrl === "string" &&
    supabaseUrl.trim() &&
    typeof supabaseAnonKey === "string" &&
    supabaseAnonKey.trim();

  if (!hasSupabaseConfig) {
    return null;
  }

  const baseUrl = supabaseUrl.replace(/\/+$/, "");
  const url = `${baseUrl}/rest/v1/${encodeURIComponent(supabaseTable || "learning_words")}`;

  const response = await axios.get(url, {
    timeout: 15000,
    headers: {
      apikey: supabaseAnonKey,
      Authorization: `Bearer ${supabaseAnonKey}`,
    },
    params: {
      select: "word,pinyin,meaning_en,meaning,frequency_rank,audio_url",
      language_code: `eq.${languageCode}`,
      order: "frequency_rank.asc",
      limit,
    },
  });

  const rows = Array.isArray(response.data) ? response.data : [];
  if (rows.length === 0) {
    return {
      language: languageCode,
      total: 0,
      source: "supabase",
      items: [],
    };
  }

  const items = rows
    .map((row) => ({
      word: String(row.word || "").trim(),
      meaning: resolveMeaningFromRow(row, targetLanguage),
      pinyin: row.pinyin ? String(row.pinyin).trim() : undefined,
      audioUrl: row.audio_url ? String(row.audio_url).trim() : undefined,
    }))
    .filter((row) => row.word && row.meaning);

  return {
    language: languageCode,
    total: items.length,
    source: "supabase",
    items,
  };
}

async function loadCache(cacheDir, languageCode, targetLanguage) {
  await ensureDirectory(cacheDir);
  const filePath = path.join(
    cacheDir,
    `${languageCode}_${targetLanguage}.json`,
  );

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
  const sources = [
    `https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/${languageCode}/${languageCode}_50k.txt`,
  ];

  // FrequencyWords stores some Chinese corpora under zh_cn.
  if (languageCode === "zh") {
    sources.push(
      "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/zh_cn/zh_cn_50k.txt",
    );
  }

  let response;
  for (const source of sources) {
    try {
      response = await axios.get(source, { timeout: 20000 });
      if (response.status === 200) {
        break;
      }
    } catch (_) {
      response = null;
    }
  }

  if (!response || response.status !== 200) {
    throw new Error(`Unable to fetch top words for ${languageCode}`);
  }

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
  supabaseUrl,
  supabaseAnonKey,
  supabaseTable,
}) {
  const resolvedLanguage = normalizeLanguage(languageCode);
  const resolvedTargetLanguage = normalizeTargetLanguage(targetLanguage);
  const resolvedLimit = Math.min(Math.max(Number(limit) || 1000, 1), 1000);

  try {
    const supabaseResult = await fetchFlashcardsFromSupabase({
      languageCode: resolvedLanguage,
      limit: resolvedLimit,
      targetLanguage: resolvedTargetLanguage,
      supabaseUrl,
      supabaseAnonKey,
      supabaseTable,
    });

    if (supabaseResult && supabaseResult.items.length > 0) {
      return supabaseResult;
    }
  } catch (_) {
    // Graceful fallback to existing generation flow.
  }

  const words = await fetchTopWords(resolvedLanguage, resolvedLimit);
  const { filePath, map } = await loadCache(
    cacheDir,
    resolvedLanguage,
    resolvedTargetLanguage,
  );

  const missingWords = words.filter((word) => !map[word]);

  if (missingWords.length > 0) {
    const translatedWords = await mapWithConcurrency(
      missingWords,
      translationConcurrency,
      async (word) => {
        const translated = await translateWord({
          word,
          sourceLanguage: resolvedLanguage,
          targetLanguage: resolvedTargetLanguage,
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
    source: "generated",
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
