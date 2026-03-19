require("dotenv").config();

const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const config = require("./config");
const { getFlashcards } = require("./services/contentService");

const app = express();

app.use(cors());
app.use(express.json());
app.use(morgan("tiny"));

app.get("/health", (_, res) => {
  res.json({ status: "ok" });
});

app.get("/api/v1/content/flashcards", async (req, res) => {
  try {
    const language = String(req.query.language || "fr");
    const limit = Number(req.query.limit || 1000);

    const result = await getFlashcards({
      languageCode: language,
      limit,
      targetLanguage: config.translationTargetLanguage,
      cacheDir: config.cacheDir,
      translationConcurrency: config.translationConcurrency,
    });

    res.json(result);
  } catch (error) {
    res.status(500).json({
      message: "Unable to generate flashcards at this time.",
      detail: error?.message || String(error),
    });
  }
});

app.listen(config.port, () => {
  console.log(`pareto-lingo-backend listening on port ${config.port}`);
});
