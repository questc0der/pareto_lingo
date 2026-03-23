require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const rateLimit = require("express-rate-limit");
const morgan = require("morgan");
const config = require("./config");
const { getFlashcards } = require("./services/contentService");

const app = express();

app.set("trust proxy", 1);

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: "cross-origin" },
  }),
);
app.use(compression());
app.use(express.json({ limit: "200kb" }));
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || config.allowedOrigins.length === 0) {
        callback(null, true);
        return;
      }

      if (config.allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error("CORS origin not allowed."));
    },
  }),
);

app.use(
  rateLimit({
    windowMs: 60 * 1000,
    max: Math.max(10, config.requestLimitPerMinute),
    standardHeaders: true,
    legacyHeaders: false,
  }),
);

app.use(morgan(config.environment === "production" ? "combined" : "tiny"));

app.get("/health", (_, res) => {
  res.json({ status: "ok" });
});

app.get("/api/v1/content/flashcards", async (req, res) => {
  try {
    const language = String(req.query.language || "fr");
    const limit = Number(req.query.limit || 1000);

    if (!Number.isFinite(limit) || limit <= 0) {
      res.status(400).json({ message: "limit must be a positive number" });
      return;
    }

    const cappedLimit = Math.min(limit, config.maxFlashcardsPerRequest);

    const result = await getFlashcards({
      languageCode: language,
      limit: cappedLimit,
      targetLanguage: config.translationTargetLanguage,
      cacheDir: config.cacheDir,
      translationConcurrency: config.translationConcurrency,
    });

    res.json(result);
  } catch (error) {
    res.status(500).json({
      message: "Unable to generate flashcards at this time.",
      detail:
        config.environment === "production"
          ? undefined
          : error?.message || String(error),
    });
  }
});

app.use((error, _req, res, _next) => {
  if (
    String(error?.message || "")
      .toLowerCase()
      .includes("cors")
  ) {
    res.status(403).json({ message: "CORS origin not allowed." });
    return;
  }

  res.status(500).json({
    message: "Internal server error.",
    detail:
      config.environment === "production"
        ? undefined
        : error?.message || String(error),
  });
});

app.listen(config.port, () => {
  console.log(`pareto-lingo-backend listening on port ${config.port}`);
});
