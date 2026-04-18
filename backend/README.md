# Pareto Lingo Backend

Backend content service for language-specific flashcards.

## Features

- `GET /api/v1/content/flashcards?language=fr&limit=200`
- Supabase-first flashcard loading (`learning_words` table), with automatic fallback to generated remote list + translation when Supabase is unavailable
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
- `SUPABASE_URL=https://<project-ref>.supabase.co`
- `SUPABASE_ANON_KEY=<anon-key>`
- `SUPABASE_FLASHCARDS_TABLE=learning_words`

3. Start server:

```bash
npm run dev
```

Server runs on `http://localhost:8080` by default.

## API behavior

- Supported languages: `fr`, `en`, `zh`
- `limit` must be an integer between `MIN_FLASHCARDS_PER_REQUEST` and `MAX_FLASHCARDS_PER_REQUEST`
- Response includes `meta.requestId` for log correlation
- If API key auth is enabled, pass `x-api-key: <your-key>`
- Response `source` value:
  - `supabase` when fetched from Supabase table
  - `generated` when fallback generator is used

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

## Mandarin 1000 For Supabase

This backend now includes a deterministic extraction pipeline for a Mandarin top-1000 deck.

Data sources used by extractor:

- Frequency: FrequencyWords Mandarin corpora (`zh_cn_50k` fallback to `zh_50k`)
- Meanings and pinyin: CC-CEDICT

Output files:

- `backend/data/seed/mandarin_1000.json`
- `backend/data/seed/mandarin_1000.csv`

### 1. Generate Mandarin seed

```bash
cd backend
npm run extract:mandarin
```

### 2. Create Supabase table

Run this SQL in Supabase SQL editor:

- `backend/supabase/sql/001_create_learning_words.sql`

Optional pronunciation metadata columns:

- `backend/supabase/sql/003_add_audio_columns.sql`

### 3. Import CSV to Supabase

Use Supabase dashboard:

1. Open `Table Editor` -> `learning_words`
2. Click `Import data from CSV`
3. Choose `backend/data/seed/mandarin_1000.csv`

The CSV columns already match table columns:

- `language_code`
- `word`
- `pinyin`
- `meaning_en`
- `frequency_rank`
- `source_freq`
- `source_dict`

### 4. Upsert pattern (optional)

If you import into a staging table first, use:

- `backend/supabase/sql/002_upsert_mandarin_words.sql`

## French + English 1000 For Supabase

Additional extraction scripts now generate 1000-word French and English seeds with the same output format.

Data sources used:

- French frequency: FrequencyWords `fr_50k`
- French meaning enrichment: Google Translate GTX API (cached locally)
- English frequency: FrequencyWords `en_50k`
- English meaning enrichment: Free Dictionary API (dictionaryapi.dev, cached locally)

### Generate French

```bash
cd backend
npm run extract:french
```

Outputs:

- `backend/data/seed/french_1000.json`
- `backend/data/seed/french_1000.csv`

### Generate English

```bash
cd backend
npm run extract:english
```

Outputs:

- `backend/data/seed/english_1000.json`
- `backend/data/seed/english_1000.csv`

You can import these CSV files into the same `learning_words` table.

## One-Command All-Language Generation

Run all extractors and generate combined artifacts in one step:

```bash
cd backend
npm run extract:all
```

This command produces:

- `backend/data/seed/all_languages_3000.json`
- `backend/data/seed/all_languages_3000.csv`
- `backend/supabase/sql/004_upsert_all_languages.sql`

`004_upsert_all_languages.sql` is ready to paste/run in Supabase SQL editor and will upsert FR/EN/ZH rows into `public.learning_words`.
