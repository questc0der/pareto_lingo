-- Optional: attach pronunciation audio metadata per word.

alter table public.learning_words
  add column if not exists audio_url text,
  add column if not exists pronunciation_source text;

create index if not exists learning_words_audio_url_idx
  on public.learning_words (language_code)
  where audio_url is not null;
