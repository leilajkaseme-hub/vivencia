# Vivência — project handoff / context

Local **experiences marketplace for Madeira island** (think GetYourGuide, but local & fair).
Brand shown on the site: **Vivência**. (Note: unrelated to chifbay.com — that came up once but is NOT used here.)

## Where it lives
- Code: single file **`index.html`** (vanilla JS, no framework, no build step).
- Hosting: **GitHub Pages**, repo `leilajkaseme-hub/vivencia`, branch `main`.
- Live: https://leilajkaseme-hub.github.io/vivencia/
- Deploy = just `git push`. Tell the user to hard-refresh (Cmd+Shift+R).

## Architecture (all inside index.html)
- **Hash routing** SPA: `#/`, `#/explore`, `#/experience/<id>`, `#/host`, `#/auth`, `#/dashboard`, `#/admin`. `router()` renders a `viewX()` string into `#app`, then binds events.
- **i18n**: dictionary `T` with `en/pt/fr/es`; `t('key', {vars})`. Auto-detects device language, persists choice, globe switcher in nav. **Keep all 4 languages at key parity** (currently 325 keys each).
- **Content**: 100% Madeira. Regions = Funchal/Câmara de Lobos/Calheta/Santana/Machico/Porto Santo. Categories in `CATS`.
- **Hero**: full-screen background video `hero.mp4` (+ `hero-poster.jpg`), real FPV drone footage; constants `HERO_VIDEO`/`HERO_POSTER` near top of script. Activity search has a custom autocomplete dropdown (`acSuggestions`). Home has a "Must-do in Madeira" section = experiences with `featured:true`.
- **Real photos** in `img/*.jpg` (optimized Madeira shots). Two food/wine experiences still use Unsplash URLs.

## Backend — Supabase
- Project URL + **anon** key are embedded in `index.html` (`SB_URL`, `SB_KEY`) — anon key is public/safe (RLS protects data). Service_role key is NOT in the repo and must never be.
- Tables: `profiles`, `host_verification` (private), `experiences`, `bookings`. RLS enabled. Schema in **`supabase_schema.sql`**, demo content + a couple ALTERs + admin policy in **`supabase_seed.sql`** (run both in Supabase SQL Editor).
- **Auth**: Supabase email/password. `me()` reads the current user's row from `STORE.profiles` (by `AUTH_UID`). Host flow is gated behind login. To make someone admin: `update public.profiles set role='admin' where id=(select id from auth.users where email='...');`
- ⚠️ In Supabase Auth settings, **"Confirm email" should be OFF** so signup logs in immediately (MVP).

## Data layer (key to understand)
- In-memory cache `STORE = {experiences, bookings, profiles}`. `loadData()` fetches from Supabase into STORE with field mappers (snake_case ↔ camelCase: `mapExp/mapBooking/mapProfile`). `DB.experiences()/bookings()/users()` now just return STORE.
- **Demo fallback**: if Supabase has no experiences, `loadData()` falls back to `demoExperiences()` (11 built-in) so the site is never empty. Demo rows have `_demo:true` and synthetic ids; bookings on them insert `exp_id:null`. Real Supabase data overrides automatically once seeded.
- Mutations (booking create, host application in `wizSubmit`, new listing, admin verify/reject/approve) write to Supabase then `await loadData()` + `router()`.
- Boot: render demo instantly → `initAuth()` → `loadData()` → re-render.

## Done so far
4-language site; device-lang auto + switcher; 100% Madeira content & copy; full-screen drone-video hero + overlay search w/ autocomplete; "Must-do in Madeira" premium section; trust badges; customer-first header; **Supabase auth (step 1)**; **listings + bookings + host profiles migrated to Supabase (step 2)** with demo fallback.

## Next / TODO
1. Run `supabase_seed.sql` in Supabase so the catalogue is real & shared (until then the demo fallback shows).
2. No realtime yet — must reload page to see others' new data (could add).
3. **Step 3 = Stripe** payments (Stripe Connect, 15% commission split). Needs a serverless function (Supabase Edge Function / Vercel) — can't be done from the static page alone.
4. SEO/blog: would need real per-page URLs + meta + sitemap (a static generator), NOT the hash SPA. Future.

## Dev workflow / gotchas
- Validate JS: extract the main `<script>` and run `node --check`. Keep the 4 i18n languages at equal key counts.
- There's a stubbed-DOM smoke test pattern used to render all routes in node without a browser.
- Commit messages end with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- ffmpeg + imagemagick installed via brew (used to compress the hero video and images).
- User communicates in French; replies in French are appreciated.
