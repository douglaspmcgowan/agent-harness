---
name: project_client_portal
description: "Client portal site for Doug's AI consulting business — repo, stack, status, deploy blockers"
metadata:
  node_type: memory
  type: project
  originSessionId: c5cef235-881d-4903-a37f-560e8d0ce93c
---

**Client Portal** — multi-customer portal for Doug's AI consulting business. Each client unlocks their page with a unique access key; Doug manages content from a browser admin dashboard (no code). Content blocks: text, rich HTML, PDF upload, Google Drive link (auto-embed), generic embed, section heading.

- **Repo:** douglaspmcgowan/client-portal (PRIVATE). Local: `C:\Users\dougl\projects\client-portal` (outside OneDrive/Drive).
- **Stack:** Next.js 16 (App Router, TS) + Tailwind v4. Supabase (Postgres + Storage) in prod; zero-config local JSON store (`.data/db.json`) for dev/tests. Admin auth = password+signed cookie; client access = code+signed cookie. No Supabase Auth.
- **Data layer:** `lib/store` DataStore interface + LocalStore + SupabaseStore, selected by presence of `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`.
- **Design:** brutalist/zine PRIMARY + dark academia ALTERNATE, `data-theme` toggle. Tokens from dpm-agent-kit `explorable/aesthetic-options.html` (#4, #23). Fonts: Space Mono+Archivo / Cormorant+Libre Caslon+IBM Plex Mono.
- **Status (2026-06-13):** built, `tsc`+`next build` clean, 12/12 Playwright tests pass (desktop+mobile), screenshots captured, pushed to GitHub.
- **Blockers before Vercel deploy:** (1) real business name/brand (placeholder "Studio Signal" in `site.config.ts`); (2) Supabase project + `supabase/schema.sql` run + env (URL, service_role, ADMIN_PASSWORD, SESSION_SECRET). Vercel CLI not installed locally.
- **Later (seams left):** Stripe (Payment Links→Checkout) per client; Cal.com scheduling embed per client.
- Demo seed: access code `DEMO-1234` → `/c/acme`. Dev admin password `letmein`.

Decisions from Doug: shared access code (not magic link) · admin dashboard in v1 · portal-only v1 (payments/scheduling later). See [[reference_dpm_sites_hub]].
