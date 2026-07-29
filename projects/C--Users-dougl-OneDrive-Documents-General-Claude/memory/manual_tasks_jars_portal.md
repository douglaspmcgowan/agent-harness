---
name: manual_tasks_jars_portal
description: "Open manual/setup tasks Doug must do himself for the Jars of Clay client portal (Supabase, admin password, domain)"
metadata:
  node_type: memory
  type: project
  originSessionId: c5cef235-881d-4903-a37f-560e8d0ce93c
---

Manual setup tasks for the **Jars of Clay client portal** that only Doug can do (accounts, keys, dashboard clicks). Full checklist lives in the Obsidian vault: `31_Business/Jars of Clay — Manual Tasks.md` (active vault `C:\Users\dougl\Main\Yoga 7 Local John 1412`).

**Open as of 2026-06-13:**

1. **Supabase (critical):** create project → run `supabase/schema.sql` → send Claude the Project URL + service_role key. Until done, the deployed portal/admin have NO persistence (landing + themes work; admin can't save; client pages empty).
2. **Change temp admin password** `ChangeMe-Jars-2026` (Vercel env `ADMIN_PASSWORD`, Production, then redeploy — or hand new value to Claude).
3. Optional: custom domain (currently https://client-portal-psi-three.vercel.app); create real clients via `/admin` once Supabase is live.

When Doug provides Supabase keys, Claude: `vercel env add NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` (production) → redeploy → live Playwright test. See [[project_client_portal]] and [[business_tasks]].
