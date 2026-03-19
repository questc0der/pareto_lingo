# Pareto Lingo Backend

Backend content service for language-specific flashcards.

## Features

- `GET /api/v1/content/flashcards?language=fr&limit=1000`
- Pulls top frequency words by language
- Auto-translates to target language (`en` by default)
- Caches translations on disk (`backend/data/cache`) to speed up future requests

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

3. Start server:

```bash
npm run dev
```

Server runs on `http://localhost:8080` by default.

## Flutter integration

The app reads backend URL from:

- `--dart-define=BACKEND_BASE_URL=http://10.0.2.2:8080` (Android emulator)
- `--dart-define=BACKEND_BASE_URL=http://<your-lan-ip>:8080` (physical device)

If backend is unavailable, the app uses fallback local generation.
