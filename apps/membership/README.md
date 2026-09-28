# Membership demo app (Funil de leads)

React + Vite single-page app for the membership demo (`m_*` tables in the
quartel-ia Supabase project). First screen: the lead funnel.

- **Data:** Supabase with the publishable key in `src/lib/supabase.ts` (public by design;
  every table is protected by Row Level Security). Users only see data of the
  club they belong to, and only team roles (admin, staff, attendant) can open
  the funnel.
- **Assistant comments** come from `m_ai_insights` (stored for the demo, not
  generated live). Lead history comes from `m_activities`.
- **Hosting:** Cloudflare Workers static assets (`wrangler.jsonc`).

## Run locally

```bash
npm install
npm run dev
```

## Deploy to Cloudflare

Either connect the GitHub repo in the Cloudflare dashboard (Workers & Pages →
Create → Import a repository) with:

| Setting | Value |
|---|---|
| Root directory | `apps/membership` |
| Build command | `npm run build` |
| Deploy command | `npx wrangler deploy` |

or, from this folder with Wrangler logged in: `npm run deploy`.

## Demo login

The app needs a Supabase Auth user linked to the club through `m_user_roles`
(role `admin`, `staff` or `attendant`) and to a person in `m_people`.
