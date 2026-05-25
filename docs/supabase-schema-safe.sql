-- ============================================================
-- a0 All Or Nothing — Supabase Schema (SAFE / IDEMPOTENT)
-- Run this even if you've run the schema before.
-- Uses IF NOT EXISTS throughout — won't break existing data.
-- ============================================================

create extension if not exists "uuid-ossp";

-- ── ENUMS (safe to re-run) ──
do $$ begin
  create type public.media_kind as enum ('audio_track','video','photo','live');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.engagement_kind as enum
    ('view','play_start','play_complete','like','save','share','repeat','skip');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.order_status as enum
    ('pending','paid','fulfilled','refunded','cancelled','disputed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.product_kind as enum
    ('physical','digital_download','digital_license','access_pass');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.subscription_status as enum
    ('active','trialing','past_due','canceled','incomplete','paused');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.artist_role as enum ('owner','manager','editor','viewer');
exception when duplicate_object then null; end $$;

-- ── PROFILES ── (already exists — just add missing columns)
create table if not exists public.profiles (
  id            uuid references auth.users(id) on delete cascade primary key,
  username      text unique,
  display_name  text not null default '',
  initials      text not null default '?',
  role          text not null default 'member',
  color_class   text not null default 'c1',
  is_kid        boolean not null default false,
  is_admin      boolean not null default false,
  bio           text,
  avatar_url    text,
  online_status text default 'offline',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Add any columns that might be missing from earlier runs
alter table public.profiles add column if not exists username      text unique;
alter table public.profiles add column if not exists is_kid        boolean not null default false;
alter table public.profiles add column if not exists is_admin      boolean not null default false;
alter table public.profiles add column if not exists color_class   text not null default 'c1';
alter table public.profiles add column if not exists bio           text;
alter table public.profiles add column if not exists avatar_url    text;
alter table public.profiles add column if not exists online_status text default 'offline';

-- ── POSTS ──
create table if not exists public.posts (
  id             uuid default uuid_generate_v4() primary key,
  author_id      uuid references public.profiles(id) on delete cascade not null,
  caption        text,
  media_url      text,
  media_type     text default 'text',
  thumbnail_url  text,
  is_story       boolean default false,
  likes_count    integer default 0,
  comments_count integer default 0,
  created_at     timestamptz not null default now()
);

-- ── LIKES ──
create table if not exists public.likes (
  id         uuid default uuid_generate_v4() primary key,
  post_id    uuid references public.posts(id) on delete cascade not null,
  user_id    uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz not null default now(),
  unique(post_id, user_id)
);

-- ── COMMENTS ──
create table if not exists public.comments (
  id         uuid default uuid_generate_v4() primary key,
  post_id    uuid references public.posts(id) on delete cascade not null,
  author_id  uuid references public.profiles(id) on delete cascade not null,
  content    text not null,
  created_at timestamptz not null default now()
);

-- ── MESSAGES ──
create table if not exists public.messages (
  id           uuid default uuid_generate_v4() primary key,
  sender_id    uuid references public.profiles(id) on delete cascade not null,
  recipient_id uuid references public.profiles(id) on delete cascade not null,
  content      text not null,
  is_read      boolean default false,
  created_at   timestamptz not null default now()
);

-- ── TASKS ──
create table if not exists public.tasks (
  id          uuid default uuid_generate_v4() primary key,
  title       text not null,
  description text,
  assigned_to uuid references public.profiles(id),
  created_by  uuid references public.profiles(id) not null,
  category    text not null default 'misc',
  priority    text not null default 'medium',
  status      text not null default 'pending',
  due_date    date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── MEETINGS ──
create table if not exists public.meetings (
  id           uuid default uuid_generate_v4() primary key,
  title        text not null,
  attendees    text[],
  meeting_date timestamptz not null,
  transcript   text,
  notes        text,
  action_items jsonb default '[]',
  next_steps   text,
  follow_up    date,
  created_by   uuid references public.profiles(id) not null,
  created_at   timestamptz not null default now()
);

-- ── CALENDAR EVENTS ──
create table if not exists public.calendar_events (
  id              uuid default uuid_generate_v4() primary key,
  title           text not null,
  description     text,
  event_date      timestamptz not null,
  end_date        timestamptz,
  platform        text,
  assigned_to     uuid references public.profiles(id),
  status          text default 'scheduled',
  google_event_id text,
  created_by      uuid references public.profiles(id) not null,
  created_at      timestamptz not null default now()
);

-- ── POMODORO SESSIONS ──
create table if not exists public.pomodoro_sessions (
  id               uuid default uuid_generate_v4() primary key,
  user_id          uuid references public.profiles(id) on delete cascade not null,
  work_type        text not null,
  duration_minutes integer not null,
  started_at       timestamptz not null,
  completed_at     timestamptz,
  notes            text,
  created_at       timestamptz not null default now()
);

-- ── ARTISTS (for public platform) ──
create table if not exists public.artists (
  id               uuid primary key default gen_random_uuid(),
  handle           text unique not null,
  display_name     text not null,
  bio              text,
  avatar_url       text,
  banner_url       text,
  verified         boolean default false,
  stripe_account_id text,
  payout_enabled   boolean default false,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

-- ── TRACKS ──
create table if not exists public.tracks (
  id               uuid default uuid_generate_v4() primary key,
  artist_id        uuid references public.artists(id) on delete restrict not null,
  title            text not null,
  duration_ms      integer,
  explicit         boolean default false,
  hls_master_r2_key text,
  master_r2_key    text,
  waveform_json    jsonb,
  visibility       text not null default 'public',
  created_at       timestamptz not null default now()
);

-- ── DRIVE MODE PREFERENCES ──
create table if not exists public.drive_mode_preferences (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  enabled           boolean default false,
  dim_level         smallint default 60,
  large_controls    boolean default true,
  reduce_motion     boolean default true,
  night_mode_after_hour smallint default 20,
  updated_at        timestamptz default now()
);

-- ── RLS ── (safe to re-enable)
alter table public.profiles          enable row level security;
alter table public.posts             enable row level security;
alter table public.likes             enable row level security;
alter table public.comments          enable row level security;
alter table public.messages          enable row level security;
alter table public.tasks             enable row level security;
alter table public.meetings          enable row level security;
alter table public.calendar_events   enable row level security;
alter table public.pomodoro_sessions enable row level security;
alter table public.artists           enable row level security;
alter table public.tracks            enable row level security;
alter table public.drive_mode_preferences enable row level security;

-- ── RLS POLICIES (drop first to avoid duplicates, then recreate) ──

-- PROFILES
drop policy if exists "profiles_read"   on public.profiles;
drop policy if exists "profiles_update" on public.profiles;
create policy "profiles_read"   on public.profiles for select using (auth.role() = 'authenticated');
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- POSTS
drop policy if exists "posts_read"   on public.posts;
drop policy if exists "posts_insert" on public.posts;
drop policy if exists "posts_delete" on public.posts;
create policy "posts_read"   on public.posts for select using (auth.role() = 'authenticated');
create policy "posts_insert" on public.posts for insert with check (auth.uid() = author_id);
create policy "posts_delete" on public.posts for delete using (auth.uid() = author_id);

-- LIKES
drop policy if exists "likes_read"   on public.likes;
drop policy if exists "likes_insert" on public.likes;
drop policy if exists "likes_delete" on public.likes;
create policy "likes_read"   on public.likes for select using (auth.role() = 'authenticated');
create policy "likes_insert" on public.likes for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.likes for delete using (auth.uid() = user_id);

-- COMMENTS
drop policy if exists "comments_read"   on public.comments;
drop policy if exists "comments_insert" on public.comments;
create policy "comments_read"   on public.comments for select using (auth.role() = 'authenticated');
create policy "comments_insert" on public.comments for insert with check (auth.uid() = author_id);

-- MESSAGES
drop policy if exists "messages_read"   on public.messages;
drop policy if exists "messages_insert" on public.messages;
create policy "messages_read"   on public.messages for select
  using (auth.uid() = sender_id or auth.uid() = recipient_id);
create policy "messages_insert" on public.messages for insert
  with check (auth.uid() = sender_id);

-- TASKS
drop policy if exists "tasks_read"   on public.tasks;
drop policy if exists "tasks_insert" on public.tasks;
drop policy if exists "tasks_update" on public.tasks;
create policy "tasks_read"   on public.tasks for select using (auth.role() = 'authenticated');
create policy "tasks_insert" on public.tasks for insert with check (auth.uid() = created_by);
create policy "tasks_update" on public.tasks for update
  using (auth.uid() = created_by or auth.uid() = assigned_to);

-- MEETINGS
drop policy if exists "meetings_read"   on public.meetings;
drop policy if exists "meetings_insert" on public.meetings;
create policy "meetings_read"   on public.meetings for select using (auth.role() = 'authenticated');
create policy "meetings_insert" on public.meetings for insert with check (auth.uid() = created_by);

-- CALENDAR EVENTS
drop policy if exists "cal_read"   on public.calendar_events;
drop policy if exists "cal_insert" on public.calendar_events;
create policy "cal_read"   on public.calendar_events for select using (auth.role() = 'authenticated');
create policy "cal_insert" on public.calendar_events for insert with check (auth.uid() = created_by);

-- POMODORO
drop policy if exists "pom_read"   on public.pomodoro_sessions;
drop policy if exists "pom_insert" on public.pomodoro_sessions;
create policy "pom_read"   on public.pomodoro_sessions for select using (auth.uid() = user_id);
create policy "pom_insert" on public.pomodoro_sessions for insert with check (auth.uid() = user_id);

-- ARTISTS (public read)
drop policy if exists "artists_read" on public.artists;
create policy "artists_read" on public.artists for select using (true);

-- TRACKS (public read for non-gated)
drop policy if exists "tracks_read" on public.tracks;
create policy "tracks_read" on public.tracks for select
  using (visibility = 'public' or auth.role() = 'authenticated');

-- DRIVE MODE (own only)
drop policy if exists "drive_read"   on public.drive_mode_preferences;
drop policy if exists "drive_upsert" on public.drive_mode_preferences;
create policy "drive_read"   on public.drive_mode_preferences for select using (auth.uid() = user_id);
create policy "drive_upsert" on public.drive_mode_preferences for all   using (auth.uid() = user_id);

-- ── TRIGGERS ──

create or replace function update_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function update_updated_at();

drop trigger if exists trg_tasks_updated on public.tasks;
create trigger trg_tasks_updated before update on public.tasks
  for each row execute function update_updated_at();

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, display_name, initials, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username',  split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'initials', upper(left(split_part(new.email,'@',1),2))),
    coalesce(new.raw_user_meta_data->>'role','member')
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── DONE ──
-- Safe to re-run at any time. No data will be lost.
-- ============================================================
-- NEXT: Update your profile rows with correct data.
-- Run one of these for each user after creating them in Auth:
-- ============================================================

-- UPDATE public.profiles SET
--   username = 'tai', display_name = 'Tai The 13th',
--   initials = 'T', role = 'admin', color_class = 'c1', is_admin = true
-- WHERE id = '<paste-uuid-from-auth-dashboard>';

-- UPDATE public.profiles SET
--   username = 'bhatoa', display_name = 'Bhatoa',
--   initials = 'BH', role = 'member', color_class = 'c2', is_admin = false
-- WHERE id = '<paste-uuid>';

-- repeat for: kellz(c3), kaia(c5,is_kid=true), salah(c6,is_kid=true),
--   royce(c7,is_kid=true), rosie(c8,is_kid=true), raphael(c1,is_kid=true),
--   myjae(c2,is_kid=true), baylingual(c3), triploc(c4),
--   shillmacc(c5), onewaynic(c6)
