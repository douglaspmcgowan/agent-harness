---
name: Edge-case test pass by default
description: Pointer to the Playwright edge-case checklist. Every new web app's Playwright suite walks the 10-item checklist, not just the happy path.
type: feedback
originSessionId: e3c49699-5ef3-4f60-a0cf-989663e728be
---

**Canonical:** [`playwright-playbook.md`](../../../../../G:/My Drive/UC Berkeley/Research/Claude Research Folder/playwright-playbook.md) → "Phase 4 — edge-case checklist for any app with state". Follow that doc; this memory is just the auto-load hook.

**The rule in one line:** Every new web app I scaffold for Doug ships with a v1 Playwright suite that walks the 10-class edge-case checklist (bounds, long text, special chars, persistence, empty state, quota, multi-tab, keyboard, mobile, print).

**Why:** Doug asked me to "test all those edge cases, please, in some way, and also make sure you have edge case testing as an automatic thing I do in whatever app playbook that you have right now." Without this, regressions in obscure paths land silently and erode trust in the app.

**How to apply:**
- When scaffolding a new app, copy the table from playwright-playbook Phase 4 into `tests/verify-live.mjs` under a `--- Edge cases ---` header.
- Build incrementally — add the edge-case assertion when the feature lands, not at v1 ship.
- When delegating to Sonnet/Codex to build a new app, include the checklist in the brief explicitly.
- Each assertion is a one-liner with `ok()` / `fail()`.

**Reference implementation:** `~/168-audit/tests/verify-live.mjs` — search for `--- Edge cases ---`.

**Doesn't apply to:** single-page docs, marketing pages, or apps with no user input.
