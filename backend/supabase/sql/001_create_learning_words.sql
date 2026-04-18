-- Supabase schema for language learning words (Mandarin first)

create table if not exists public.learning_words (
  id bigserial primary key,
  language_code text not null,
  word text not null,
  pinyin text,
  meaning_en text not null,
  frequency_rank integer not null check (frequency_rank > 0),
  source_freq text,
  source_dict text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint learning_words_lang_word_unique unique (language_code, word)
);

create index if not exists learning_words_language_rank_idx
  on public.learning_words (language_code, frequency_rank);

create index if not exists learning_words_language_word_idx
  on public.learning_words (language_code, word);

create or replace function public.set_learning_words_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_learning_words_updated_at on public.learning_words;
create trigger trg_learning_words_updated_at
before update on public.learning_words
for each row
execute function public.set_learning_words_updated_at();

alter table public.learning_words enable row level security;

-- Public read policy (safe for mobile/web clients)
drop policy if exists "learning_words_read_all" on public.learning_words;
create policy "learning_words_read_all"
on public.learning_words
for select
using (true);

-- No public writes by default.
