const path = require("path");

module.exports = {
  port: Number(process.env.PORT || 8080),
  translationTargetLanguage: process.env.TRANSLATION_TARGET_LANGUAGE || "en",
  translationConcurrency: Number(process.env.TRANSLATION_CONCURRENCY || 8),
  cacheDir: path.join(__dirname, "..", "data", "cache"),
};
