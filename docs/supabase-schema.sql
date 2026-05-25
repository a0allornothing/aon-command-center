-- ============================================================
-- a0 All Or Nothing — Supabase Database Schema
-- Run this entire file in Supabase SQL Editor
-- Dashboard → SQL Editor → New Query → Paste → Run
-- ============================================================

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- ── PROFILES TABLE ──────────────────────────────────────────
-- Extends auth.users with app-specific fields
create table public.profiles (
  id            uuid references auth.users(id) on delete cascade primary key,
  username      text unique not null,
  display_name  text not null,
  initials      text not null,
  role          text not null default 'member',
    -- roles: admin | staff | artist | kid | member
  color_class   text not null default 'c1',
    -- c1–c8 (maps to gradient classes in app CSS)
  is_kid        boolean not null default false,
  is_admin      boolean not null default false,
  bio           text,
  avatar_url    text,
  online_status text default 'offline',
    -- offline | online | busy
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ── POSTS TABLE ─────────────────────────────────────────────
create table public.posts (
  id             uuid default uuid_generate_v4() primary key,
  author_id      uuid references public.profiles(id) on delete cascade not null,
  caption        text,
  media_url      text,
  media_type     text default 'text',
    -- photo | video | beat | text
  thumbnail_url  text,
  is_story       boolean default false,
  likes_count    integer default 0,
  comments_count integer default 0,
  created_at     timestamptz not null default now()
);

-- ── LIKES TABLE ──────────────────────────────────────────────
create table public.likes (
  id         uuid default uuid_generate_v4() primary key,
  post_id    uuid references public.posts(id) on delete cascade not null,
  user_id    uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz not null default now(),
  unique(post_id, user_id)
);

-- ── COMMENTS TABLE ───────────────────────────────────────────
create table public.comments (
  id         uuid default uuid_generate_v4() primary key,
  post_id    uuid references public.posts(id) on delete cascade not null,
  author_id  uuid references public.profiles(id) on delete cascade not null,
  content    text not null,
  created_at timestamptz not null default now()
);

-- ── MESSAGES (DMs) TABLE ────────────────────────────────────
create table public.messages (
  id           uuid default uuid_generate_v4() primary key,
  sender_id    uuid references public.profiles(id) on delete cascade not null,
  recipient_id uuid references public.profiles(id) on delete cascade not null,
  content      text not null,
  is_read      boolean default false,
  created_at   timestamptz not null default now()
);

-- ── TASKS TABLE ──────────────────────────────────────────────
create table public.tasks (
  id          uuid default uuid_generate_v4() primary key,
  title       text not null,
  description text,
  assigned_to uuid references public.profiles(id),
  created_by  uuid references public.profiles(id) not null,
  category    text not null default 'misc',
    -- daily | business | home | fight_league | artists | misc
  priority    text not null default 'medium',
    -- urgent | high | medium | low
  status      text not null default 'pending',
    -- pending | in_progress | done
  due_date    date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── MEETINGS TABLE ───────────────────────────────────────────
create table public.meetings (
  id           uuid default uuid_generate_v4() primary key,
  title        text not null,
  attendees    text[],              -- array of usernames
  meeting_date timestamptz not null,
  transcript   text,
  notes        text,
  action_items jsonb default '[]', -- [{text, done, assigned_to}]
  next_steps   text,
  follow_up    date,
  created_by   uuid references public.profiles(id) not null,
  created_at   timestamptz not null default now()
);

-- ── CALENDAR EVENTS TABLE ────────────────────────────────────
create table public.calendar_events (
  id              uuid default uuid_generate_v4() primary key,
  title           text not null,
  description     text,
  event_date      timestamptz not null,
  end_date        timestamptz,
  platform        text,   -- ig | tiktok | youtube | twitter | personal | business
  assigned_to     uuid references public.profiles(id),
  status          text default 'scheduled', -- scheduled | posted | cancelled
  google_event_id text,
  created_by      uuid references public.profiles(id) not null,
  created_at      timestamptz not null default now()
);

-- ── POMODORO SESSIONS TABLE ──────────────────────────────────
create table public.pomodoro_sessions (
  id               uuid default uuid_generate_v4() primary key,
  user_id          uuid references public.profiles(id) on delete cascade not null,
  work_type        text not null,
    -- music | content | admin | marketing | calls | workout | coding | school | misc
  duration_minutes integer not null,
  started_at       timestamptz not null,
  completed_at     timestamptz,
  notes            text,
  created_at       timestamptz not null default now()
);

-- ── ROW LEVEL SECURITY ───────────────────────────────────────
alter table public.profiles          enable row level security;
alter table public.posts             enable row level security;
alter table public.likes             enable row level security;
alter table public.comments          enable row level security;
alter table public.messages          enable row level security;
alter table public.tasks             enable row level security;
alter table public.meetings          enable row level security;
alter table public.calendar_events   enable row level security;
alter table public.pomodoro_sessions enable row level security;

-- PROFILES: any authenticated user can read; only owner can update
create policy "profiles_read"   on public.profiles for select using (auth.role() = 'authenticated');
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- POSTS: authenticated users read/insert own; delete own
create policy "posts_read"   on public.posts for select using (auth.role() = 'authenticated');
create policy "posts_insert" on public.posts for insert with check (auth.uid() = author_id);
create policy "posts_delete" on public.posts for delete using (auth.uid() = author_id);

-- LIKES
create policy "likes_read"   on public.likes for select using (auth.role() = 'authenticated');
create policy "likes_insert" on public.likes for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.likes for delete using (auth.uid() = user_id);

-- COMMENTS
create policy "comments_read"   on public.comments for select using (auth.role() = 'authenticated');
create policy "comments_insert" on public.comments for insert with check (auth.uid() = author_id);

-- MESSAGES: sender and recipient only
create policy "messages_read"   on public.messages for select using (auth.uid() = sender_id or auth.uid() = recipient_id);
create policy "messages_insert" on public.messages for insert with check (auth.uid() = sender_id);

-- TASKS: all authenticated users read; only creator/assignee update
create policy "tasks_read"   on public.tasks for select using (auth.role() = 'authenticated');
create policy "tasks_insert" on public.tasks for insert with check (auth.uid() = created_by);
create policy "tasks_update" on public.tasks for update using (auth.uid() = created_by or auth.uid() = assigned_to);

-- MEETINGS
create policy "meetings_read"   on public.meetings for select using (auth.role() = 'authenticated');
create policy "meetings_insert" on public.meetings for insert with check (auth.uid() = created_by);

-- CALENDAR EVENTS
create policy "cal_read"   on public.calendar_events for select using (auth.role() = 'authenticated');
create policy "cal_insert" on public.calendar_events for insert with check (auth.uid() = created_by);

-- POMODORO: own sessions only
create policy "pom_read"   on public.pomodoro_sessions for select using (auth.uid() = user_id);
create policy "pom_insert" on public.pomodoro_sessions for insert with check (auth.uid() = user_id);

-- ── TRIGGERS ─────────────────────────────────────────────────

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger trg_profiles_updated before update on public.profiles
  for each row execute function update_updated_at();

create trigger trg_tasks_updated before update on public.tasks
  for each row execute function update_updated_at();

-- Auto-create profile row when a new user signs up via Supabase Auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, display_name, initials, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username',  split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'initials', upper(left(split_part(new.email,'@',1), 2))),
    coalesce(new.raw_user_meta_data->>'role', 'member')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── STORAGE BUCKETS ──────────────────────────────────────────
-- Run these separately in the Supabase Storage dashboard
-- OR uncomment and run here:
-- insert into storage.buckets (id, name, public) values ('posts', 'posts', false);
-- insert into storage.buckets (id, name, public) values ('avatars', 'avatars', false);
-- insert into storage.buckets (id, name, public) values ('beats', 'beats', false);

-- ── AFTER SCHEMA: SEED PROFILE DATA ──────────────────────────
-- After creating users in Auth dashboard, update their profiles:
-- 
-- update public.profiles set
--   display_name = 'Tai The 13th', initials = 'T', role = 'admin',
--   color_class = 'c1', is_admin = true, username = 'tai'
-- where id = '<tai-auth-uuid>';
--
-- Repeat for: bhatoa(c2,president), kellz(c3,staff),
--   keke(c4,kid,is_kid=true), kaia(c5,kid), salah(c6,kid),
--   royce(c7,kid), rosie(c8,kid), raphael(c1,kid), myjae(c2,kid),
--   baylingual(c3,artist), triploc(c4,artist),
--   shillmacc(c5,artist), onewaynic(c6,artist)

-- ── DONE ─────────────────────────────────────────────────────
-- Schema complete. Next steps:
-- 1. supabase.com → New Project
-- 2. SQL Editor → paste and run this file
-- 3. Authentication → Users → create all 14 accounts
-- 4. Update profiles table with correct data for each user
-- 5. Copy Project URL + anon key into app index.html
