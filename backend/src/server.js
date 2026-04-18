require("dotenv").config();

const crypto = require("crypto");
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const rateLimit = require("express-rate-limit");
const morgan = require("morgan");
const config = require("./config");
const {
  getFlashcards,
  getSupportedLanguages,
} = require("./services/contentService");

const app = express();
const supportedLanguages = new Set(getSupportedLanguages());

function createHttpError(status, message, code, detail) {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  error.detail = detail;
  return error;
}

function sanitizePositiveInteger(value) {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  if (!/^\d+$/.test(String(value).trim())) {
    return NaN;
  }

  return Number(value);
}

function validateFlashcardQuery(req, _res, next) {
  const rawLanguage = String(req.query.language || "fr")
    .toLowerCase()
    .trim();

  if (!supportedLanguages.has(rawLanguage)) {
    next(
      createHttpError(
        400,
        `Unsupported language '${rawLanguage}'.`,
        "INVALID_LANGUAGE",
        { supportedLanguages: Array.from(supportedLanguages) },
      ),
    );
    return;
  }

  const parsedLimit = sanitizePositiveInteger(req.query.limit);
  if (Number.isNaN(parsedLimit)) {
    next(
      createHttpError(
        400,
        "limit must be a positive integer.",
        "INVALID_LIMIT",
      ),
    );
    return;
  }

  const requestedLimit = parsedLimit ?? config.defaultFlashcardsPerRequest;
  const minLimit = Math.max(1, config.minFlashcardsPerRequest);
  const maxLimit = Math.max(minLimit, config.maxFlashcardsPerRequest);

  if (requestedLimit < minLimit || requestedLimit > maxLimit) {
    next(
      createHttpError(
        400,
        `limit must be between ${minLimit} and ${maxLimit}.`,
        "LIMIT_OUT_OF_RANGE",
        { minLimit, maxLimit },
      ),
    );
    return;
  }

  const rawTargetLanguage = String(
    req.query.targetLanguage || config.translationTargetLanguage,
  )
    .toLowerCase()
    .trim();

  if (!/^[a-z]{2,8}(?:-[a-z]{2,8})?$/.test(rawTargetLanguage)) {
    next(
      createHttpError(
        400,
        "targetLanguage must be a valid language code.",
        "INVALID_TARGET_LANGUAGE",
      ),
    );
    return;
  }

  req.flashcardQuery = {
    language: rawLanguage,
    limit: requestedLimit,
    targetLanguage: rawTargetLanguage,
  };
  next();
}

function requireApiKey(req, _res, next) {
  if (!config.requireApiKey) {
    next();
    return;
  }

  if (!Array.isArray(config.apiKeys) || config.apiKeys.length === 0) {
    next(
      createHttpError(
        503,
        "API key auth is not configured.",
        "AUTH_NOT_CONFIGURED",
      ),
    );
    return;
  }

  const apiKey = req.get("x-api-key");
  if (!apiKey || !config.apiKeys.includes(apiKey)) {
    next(createHttpError(401, "Unauthorized", "INVALID_API_KEY"));
    return;
  }

  next();
}

const flashcardsRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Math.max(5, config.flashcardsRequestLimitPerMinute),
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "RATE_LIMITED",
    message: "Too many flashcard requests. Please retry later.",
  },
});

app.set("trust proxy", 1);

app.use((req, res, next) => {
  req.requestId = crypto.randomUUID();
  req.startedAt = process.hrtime.bigint();
  res.setHeader("x-request-id", req.requestId);
  next();
});

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

app.use(
  morgan(config.environment === "production" ? "combined" : "tiny", {
    skip(req) {
      return req.path === "/health";
    },
  }),
);

app.use((req, res, next) => {
  res.on("finish", () => {
    if (req.path === "/health") return;

    const startedAt = req.startedAt || process.hrtime.bigint();
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
    const payload = {
      level: "info",
      event: "http_request",
      requestId: req.requestId,
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      durationMs: Number(durationMs.toFixed(1)),
      userAgent: req.get("user-agent"),
      ip: req.ip,
      timestamp: new Date().toISOString(),
    };
    console.log(JSON.stringify(payload));
  });
  next();
});

app.get("/health", (_, res) => {
  res.json({ status: "ok", environment: config.environment });
});

app.get(
  "/api/v1/content/flashcards",
  flashcardsRateLimiter,
  requireApiKey,
  validateFlashcardQuery,
  async (req, res, next) => {
    try {
      const { language, limit, targetLanguage } = req.flashcardQuery;

      const result = await getFlashcards({
        languageCode: language,
        limit,
        targetLanguage,
        cacheDir: config.cacheDir,
        translationConcurrency: config.translationConcurrency,
        supabaseUrl: config.supabaseUrl,
        supabaseAnonKey: config.supabaseAnonKey,
        supabaseTable: config.supabaseFlashcardsTable,
      });

      res.json({
        ...result,
        meta: {
          requestId: req.requestId,
        },
      });
    } catch (error) {
      next(
        createHttpError(
          502,
          "Unable to generate flashcards at this time.",
          "FLASHCARD_GENERATION_FAILED",
          error?.message || String(error),
        ),
      );
    }
  },
);

app.use((error, _req, res, _next) => {
  const requestId = _req.requestId;

  if (
    String(error?.message || "")
      .toLowerCase()
      .includes("cors")
  ) {
    res.status(403).json({
      code: "CORS_BLOCKED",
      message: "CORS origin not allowed.",
      requestId,
    });
    return;
  }

  const status = Number(error?.status) || 500;
  const code = error?.code || "INTERNAL_SERVER_ERROR";

  if (status >= 500) {
    console.error(
      JSON.stringify({
        level: "error",
        event: "request_failed",
        requestId,
        status,
        code,
        message: error?.message,
        stack: error?.stack,
        timestamp: new Date().toISOString(),
      }),
    );
  }

  res.status(status).json({
    code,
    message: error?.message || "Internal server error.",
    requestId,
    detail:
      config.environment === "production"
        ? undefined
        : error?.detail || error?.message || String(error),
  });
});

app.listen(config.port, () => {
  console.log(`pareto-lingo-backend listening on port ${config.port}`);
});
