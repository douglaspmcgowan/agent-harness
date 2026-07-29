---
name: project-berkeley-house
description: "Berkeley House — 7-room co-op property management site at 1636½ 63rd St, Berkeley CA; Next.js 16, Supabase, Stripe ACH, Gmail SMTP, Twilio SMS"
metadata:
  node_type: memory
  type: project
  originSessionId: 4800f73c-4931-4911-8fd9-58448fc59d36
---

Next.js 16 (App Router) + React 19 + TypeScript + Tailwind CSS 4 + shadcn-ui property management site for a 7-room co-op house. Owner: Douglas McGowan (douglaspmcgowan@gmail.com). Admin notifications → 1636berkeley@gmail.com.

**Live:** https://berkeley-house.vercel.app (auto-deploys from `main`)
**Supabase project ref:** `nmksafjyroefeazymfha` (https://nmksafjyroefeazymfha.supabase.co)

**Key files:**

- `app/page.tsx` — public listing (reads rooms from Supabase live)
- `app/apply/` — subtenant intake form → creates row in `tenants` table
- `app/admin/` — admin dashboard (inquiries, tours, rooms editor, tenants, payments, maintenance)
- `app/admin/rooms/RoomsClient.tsx` — room status toggle UI
- `app/api/subtenant-intake/route.ts` — intake form API
- `app/api/tour-request/route.ts` — tour form API
- `app/api/admin/rooms/route.ts` — PATCH room status (admin only)
- `lib/supabase/schema.sql` — full DB schema
- `lib/stripe.ts` — Stripe client; flat rate $1,095/mo in Stripe (per-room pricing in DB only)
- `.claude/setup.sh` — SessionStart hook: npm install, Supabase CLI, token fallback, project link

**DB tables:** `rooms` (7 rows, A–G mapped via roomDisplayLabel()), `tenants`, `inquiries` (has `available_times text[]`), `payments`

**Per-room rents (DB only, not shown publicly):** A=$1,200 · B=$1,200 · C=$1,100 · D=$1,200 · E=$1,200 · F=$1,200 · G=$900

**Supabase CLI note:** `supabase db query --linked` hangs in cloud; use management API:

```
curl -s -X POST "https://api.supabase.com/v1/projects/nmksafjyroefeazymfha/database/query" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"query": "SQL HERE"}'
```

Token env var: `SUPABASE_ACCESS_TOKEN` (was typo `SUPABASE_ACCESS_TOKRN` — setup.sh handles both).

**Auth (rebuilt 2026-06-21):** Admin at `/admin` is locked to an EMAIL ALLOWLIST (`lib/auth/allowlist.ts` = douglaspmcgowan@gmail.com + 1636berkeley@gmail.com), enforced defense-in-depth at proxy.ts, getAuthedUser(), admin layout, every /api/admin route, auth callback, AND Postgres RLS (`lower(auth.jwt()->>'email')`). Login is email+PASSWORD (signInWithPassword), not magic link; password = `trust3in` (both accounts); self-service change at `/admin/account`; break-glass `scripts/set-admin-password.js`. Supabase: `disable_signup=true`, `password_min_length=8` (HIBP leaked-pw is Pro-only). Security headers in next.config.ts. RLS verified by `scripts/security-rls-probe.js`. Auth e2e in `e2e/admin-security.spec.ts`.

**Applications workflow (2026-06-21):** public intake (`/apply`) creates an `applications` row (status submitted), NOT a tenant; admin reviews at `/admin/applications` and "Approve & convert" creates the tenant (assign room A–G + lease + deposit). Decision emails are DRAFTED (no auto-send); applicant gets an auto-ack on submit. Tenants editable inline; rooms shown as LETTERS A–G (`lib/rooms.ts`, `rooms.label`='A'..'G'; `number` is internal sort only). Migrations 002–006. **RLS gotcha learned:** an RLS policy needs the base table GRANT to the role too — `revoke all ... from authenticated` breaks the admin even with a matching policy (fixed in 006).

**Pending (Phase 2b, offered):** tokenized `/t/[token]/pay` + retire `/pay/[tenantId]` + delete `tenant/lookup` IDOR oracle; rent charges/reminders + Stripe webhook idempotency; maintenance + comms workflow.

**⚠️ Rotate creds:** during the 2026-06-21 security audit a subagent's misfired shell dumped env vars into its own transcript — told Doug to rotate GITHUB_PAT / OPENAI_API_KEY / GOOGLE_OAUTH_CLIENT_SECRET / AMAX_ELITE_PASSWORD / SUPABASE_ACCESS_TOKEN.

**What works:** Public listing live from Supabase, tour form → inquiries + Gmail + Twilio SMS, intake form → tenants table + Gmail, admin dashboard UI, Inter + Fraunces fonts.

**Not yet wired:** Stripe webhooks not registered in Stripe dashboard, no tenants seeded for payments, Twilio end-to-end unconfirmed, GOOGLE_SERVICE_ACCOUNT_JSON may not be in Vercel, test data in DB (test inquiry + test-subtenant@example.com tenant) not cleaned up.

**Lease generator:** `scripts/generate-lease.js` — CLI tool that fetches tenant from Supabase by name/UUID and generates a Word doc sublease (Exhibit B template). Output → `output/lease-<slug>-<date>.docx` (gitignored). Run via `vercel env run --environment=production -- node scripts/generate-lease.js "Name"`. Add `--email` flag to also send the lease to the tenant via Gmail SMTP (nodemailer).

**Email sender for tenant comms:** `1636berkeley@gmail.com`. `GMAIL_APP_PASSWORD` in Vercel env is for this account. Gmail MCP in Claude is only connected to `douglaspmcgowan@gmail.com` — cannot draft from 1636berkeley via MCP directly.

**First subtenant:** Rhonda Diciedue (rdiciedue@gmail.com), Room E, $1,200/mo, July 1 2026 – June 30 2027. Tenant ID: `733c02fb-1058-4fd6-85c4-08541fbb3829`. Lease generated 2026-06-14.

**DocuSign:** MCP is connected but only has `sendReminder` + `updateEnvelopeRecipients` — cannot create new envelopes. `DOCUSIGN-HANDOFF.md` in repo root is a self-contained prompt for a fully-connected DocuSign session to send Rhonda's lease.

**Why:** Doug's personal income property.
**How to apply:** Always push to `main`; never create feature branches unless explicitly asked. Repo: `douglaspmcgowan/berkeley-house`.
