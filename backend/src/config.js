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

module.exports = {
  port: parseNumber(process.env.PORT, 8080),
  environment: process.env.NODE_ENV || "development",
  translationTargetLanguage: process.env.TRANSLATION_TARGET_LANGUAGE || "en",
  translationConcurrency: parseNumber(process.env.TRANSLATION_CONCURRENCY, 8),
  requestLimitPerMinute: parseNumber(process.env.REQUEST_LIMIT_PER_MINUTE, 120),
  maxFlashcardsPerRequest: parseNumber(
    process.env.MAX_FLASHCARDS_PER_REQUEST,
    1000,
  ),
  allowedOrigins: parseOrigins(process.env.ALLOWED_ORIGINS),
  cacheDir: path.join(__dirname, "..", "data", "cache"),
};
