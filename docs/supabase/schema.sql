-- ANKI-HUB-iOS Supabase schema (2026-07-05)
-- Supabase Dashboard → SQL Editor で実行してください。
-- 既存テーブルがある場合は DROP 後に再作成するか、差分を手動マージしてください。

-- extensions
create extension if not exists "pgcrypto";

-- ========== users ==========
create table if not exists public.users (
  id uuid primary key,
  email text unique not null,
  created_at timestamptz default now(),
  last_login timestamptz
);

alter table public.users enable row level security;

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own" on public.users
  for select using (auth.uid() = id);

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own" on public.users
  for insert with check (auth.uid() = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

-- ========== invitations ==========
create table if not exists public.invitations (
  id bigserial primary key,
  code text unique not null,
  email text,
  is_used boolean default false,
  used_by uuid references public.users(id),
  used_at timestamptz,
  created_at timestamptz default now()
);

alter table public.invitations enable row level security;

drop policy if exists "invitations_select_used_by" on public.invitations;
create policy "invitations_select_used_by" on public.invitations
  for select using (used_by = auth.uid());

drop policy if exists "invitations_update_unused" on public.invitations;
create policy "invitations_update_unused" on public.invitations
  for update using (is_used = false);

-- ========== study (sync blob) ==========
create table if not exists public.study (
  id bigserial primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  app_id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now(),
  unique (user_id, app_id)
);

alter table public.study enable row level security;

drop policy if exists "study_all_own" on public.study;
create policy "study_all_own" on public.study
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ========== mistake_reports ==========
create table if not exists public.mistake_reports (
  id bigserial primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  subject text,
  word_id text,
  term text,
  correct text,
  note text,
  created_at timestamptz default now()
);

alter table public.mistake_reports enable row level security;

drop policy if exists "mistake_reports_insert_own" on public.mistake_reports;
create policy "mistake_reports_insert_own" on public.mistake_reports
  for insert with check (user_id = auth.uid());

drop policy if exists "mistake_reports_select_own" on public.mistake_reports;
create policy "mistake_reports_select_own" on public.mistake_reports
  for select using (user_id = auth.uid());

-- ========== seed: 開発用招待コード（本番では削除/変更） ==========
insert into public.invitations (code, email, is_used)
values ('DEV-INVITE-2026', null, false)
on conflict (code) do nothing;

-- ========== Supabase Auth 設定チェックリスト ==========
-- 1. Authentication → URL Configuration
--    Site URL: sugwranki://login-callback （または任意 + Redirect URLs に追加）
--    Redirect URLs: sugwranki://login-callback
-- 2. Authentication → Providers → Google → Enable
-- 3. Google Cloud Console OAuth: iOS client for com.ankihub.ios
-- 4. Authentication → Users でテストログイン確認
