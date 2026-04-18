const path = require("path");

function parseNumber(input, fallback) {
  const value = Number(input);
  if (!Number.isFinite(value)) return fallback;
  return value;
}

function parseOrigins(input) {
  if (!input || !String(input).trim()) return [];
  return String(input)
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
}

function parseApiKeys(input) {
  if (!input || !String(input).trim()) return [];
  return String(input)
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
}

module.exports = {
  port: parseNumber(process.env.PORT, 8080),
  environment: process.env.NODE_ENV || "development",
  translationTargetLanguage: process.env.TRANSLATION_TARGET_LANGUAGE || "en",
  translationConcurrency: parseNumber(process.env.TRANSLATION_CONCURRENCY, 8),
  requestLimitPerMinute: parseNumber(process.env.REQUEST_LIMIT_PER_MINUTE, 120),
  flashcardsRequestLimitPerMinute: parseNumber(
    process.env.FLASHCARDS_REQUEST_LIMIT_PER_MINUTE,
    60,
  ),
  maxFlashcardsPerRequest: parseNumber(
    process.env.MAX_FLASHCARDS_PER_REQUEST,
    1000,
  ),
  minFlashcardsPerRequest: parseNumber(
    process.env.MIN_FLASHCARDS_PER_REQUEST,
    1,
  ),
  defaultFlashcardsPerRequest: parseNumber(
    process.env.DEFAULT_FLASHCARDS_PER_REQUEST,
    200,
  ),
  allowedOrigins: parseOrigins(process.env.ALLOWED_ORIGINS),
  apiKeys: parseApiKeys(process.env.API_KEYS),
  requireApiKey:
    String(process.env.REQUIRE_API_KEY || "false").toLowerCase() === "true",
  cacheDir: path.join(__dirname, "..", "data", "cache"),
  supabaseUrl: process.env.SUPABASE_URL || "",
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY || "",
  supabaseFlashcardsTable:
    process.env.SUPABASE_FLASHCARDS_TABLE || "learning_words",
};
