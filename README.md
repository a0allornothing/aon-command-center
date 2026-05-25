# a0 All Or Nothing — Command Center

Private internal platform for Tai The 13th and the a0 team.

## Quick Deploy
1. Add Anthropic API key to `index.html`
2. Add Supabase URL + anon key to `index.html`
3. Run `docs/supabase-schema.sql` in Supabase SQL Editor
4. Push to GitHub — Netlify auto-deploys

See `docs/` for full setup instructions.

## Features
- Matrix login with Supabase Auth
- Private IG-style feed
- HQ dashboard with progress tracking
- Task management (localStorage + Supabase)
- Google Calendar integration
- Claude AI Schedule Assistant
- Pomodoro focus timer
- TV War Room mode
- Team roster (14 members)
- PWA — installable on iOS/Android

## Stack
- Frontend: HTML/CSS/JS (PWA)
- Auth + DB: Supabase
- AI: Claude claude-sonnet-4-20250514 + Google Calendar MCP
- Hosting: Netlify
- Calendar: Google Calendar API

## Users
14 accounts: Tai (admin), Bhatoa, Kellz, artists (4), family (7)

## Environment Variables (add to index.html)
- `SUPABASE_URL` — from supabase.com project settings
- `SUPABASE_KEY` — anon key from supabase.com
- `ANTHROPIC_KEY` — from console.anthropic.com
- `INVITE_CODE` — AON2024 (change before going live)
