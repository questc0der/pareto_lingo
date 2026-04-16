# Pareto Lingo Backend

Backend content service for language-specific flashcards.

## Features

- `GET /api/v1/content/flashcards?language=fr&limit=200`
- Pulls top frequency words by language
- Auto-translates to target language (`en` by default)
- Caches translations on disk (`backend/data/cache`) to speed up future requests
- Production middleware: `helmet`, `compression`, `express-rate-limit`, env-based CORS
- Optional API-key auth (`x-api-key`) for protected deployments
- Structured error responses and request IDs (`x-request-id`) for observability

## Setup

1. Install dependencies:

```bash
cd backend
npm install
```

2. Create env file:

```bash
cp .env.example .env
```

Important env vars:

- `NODE_ENV=production`
- `ALLOWED_ORIGINS=https://<your-frontend-domain>` (comma-separated for multiple)
- `REQUEST_LIMIT_PER_MINUTE=120`
- `FLASHCARDS_REQUEST_LIMIT_PER_MINUTE=60`
- `DEFAULT_FLASHCARDS_PER_REQUEST=200`
- `MIN_FLASHCARDS_PER_REQUEST=1`
- `MAX_FLASHCARDS_PER_REQUEST=1000`
- `REQUIRE_API_KEY=true` (optional)
- `API_KEYS=<key1>,<key2>` (required if `REQUIRE_API_KEY=true`)

3. Start server:

```bash
npm run dev
```

Server runs on `http://localhost:8080` by default.

## API behavior

- Supported languages: `fr`, `es`, `de`
- `limit` must be an integer between `MIN_FLASHCARDS_PER_REQUEST` and `MAX_FLASHCARDS_PER_REQUEST`
- Response includes `meta.requestId` for log correlation
- If API key auth is enabled, pass `x-api-key: <your-key>`

## Render deployment

1. Create a new **Web Service** from the `backend` folder.
2. Build command: `npm install`
3. Start command: `npm start`
4. Set environment variables from `.env.example`.
5. Set `ALLOWED_ORIGINS` to your deployed Flutter web domain (if web client is used).

## Flutter integration

The app reads backend URL from:

- `--dart-define=BACKEND_BASE_URL=http://10.0.2.2:8080` (Android emulator)
- `--dart-define=BACKEND_BASE_URL=http://<your-lan-ip>:8080` (physical device)

If backend is unavailable, the app uses fallback local generation.
