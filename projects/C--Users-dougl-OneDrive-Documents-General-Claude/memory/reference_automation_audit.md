---
name: reference-automation-audit
description: "Where the June 2026 automation audit lives + the two design skills installed; ranked build list for automating Doug's recurring Claude tasks"
metadata:
  node_type: memory
  type: reference
  originSessionId: ec2a4f00-b24c-4e29-8aea-692de01f9655
---

Automation audit of ~2 weeks of Claude sessions (30 sessions / 389 prompts) lives at
`<vault>\Claude\Automation Audit June 2026\` — 12 docs: `00 - START HERE — Overview`, `01`–`09` by task
category, `10 - Master Recommendations` (ranked build order), `11 - Berkeley House Cloud Handoff`, `12 - Berkeley House`.

**Berkeley deep-dive (2026-06-14):** `…\Automation Audit June 2026\Berkeley House Deep-Dive\` — ran the full
audit process over the byte-complete berkeley transcript via 6 parallel Sonnet agents (one per theme) →
`B1`–`B6` + ranked synthesis `B0 - Deep-Dive Synthesis`. **Convergent #1 build** (4 of 6 agents independently):
a read-only `/api/healthz` env-var doctor (live commit SHA + boolean env presence, never values) + a
PostToolUse deploy-watch hook — retires the "did you push?" loop, temp-code-to-prod debugging, env-var
invisibility, and Doug's "set an automatic timer" ask in one. **Correction:** the allowlist generator Doug
hand-wrote is ALREADY the installed `fewer-permission-prompts` skill (needs a SessionStart trigger, not a build).
**Cross-project merge DONE (2026-06-14):** `…\Automation Audit June 2026\MERGED — Cross-Project Automations.md`.
The REAL AMAX automation source is **`C:\Users\dougl\projects\legal-solutions-website\docs\agentic-loop-roadmap.md`**
(a full intake→generate→deploy→monitor roadmap), NOT the vault SEO docs — found via the AMAX session 4e60dd24
(06-13). The vault `31_Business\AMAX Elite Notary (Legal Solutions)\` holds only SEO/GEO ops docs. Headline of the
merge: Berkeley + AMAX are the same Next.js/Vercel machine built twice; shared core = deploy-agent-via-Vercel-**API**
(both hit the CLI-hides-BLOCKED/“did-you-push” bug) · security-grep-before-deploy · single-source-of-truth/`brief.yaml` ·
validator(build+playwright+JSON-LD) · CLAUDE.md/doc auto-sync · `fewer-permission-prompts`→SessionStart. AMAX adds the
forward-looking "agency-in-a-box" intake→deploy pipeline. **Compartmentalization gotcha:** the audit's CURRENT-TASK.md
lives in the General Claude catch-all cwd, so concurrent sessions there share it (one literally re-did the merge wrong);
closed it out to stop collisions. Legal-solutions repo: `C:\Users\dougl\projects\legal-solutions-website` (site amaxeliteseals.org).

Headline: build the **Tier-0 hooks** first (obsidian-md lint, AI-isms grep gate, LaTeX/file diff-gate,
`/save-to-vault` skill + Stop reminder, SessionStart preflight) — they attack the cross-cutting friction
(blind rendering, manual "put it in obsidian", silent edit loss). Then the **Obsidian Canvas Compiler +
Linter** (doc 04) — biggest single time-sink (the 69-prompt profile-canvas saga).

Two design skills installed 2026-06-13 → `~/.claude/skills/`: **`design-taste`** (leonxlnx/taste-skill,
frontmatter name `design-taste-frontend`) and **`impeccable`** (pbakaus/impeccable, has `npx impeccable`
CLI + reference sub-commands). Recorded in [[reference_toolkit_map]]. See [[feedback_ai_isms]] — doc 02
recommends wiring AI-isms enforcement into a hook + a `/design-pass` skill that chains these two.

**How to pull a Claude cloud/desktop session (non-obvious — reusable method, ranked most→least reliable):**

0. **BEST: have the cloud session export its own transcripts.** A cloud Claude Code session can write its raw
   `~/.claude/projects/**/*.jsonl` into the repo (e.g. a `transcripts/` folder) and the user downloads the repo
   zip. This is byte-complete and beats every scrape. June 2026: Doug did exactly this → `berkeley-house-transcripts.zip`
   (19 .jsonl). Parse: dedupe every record by `uuid` (files cross-reference/resume each other), group by `sessionId`,
   sort by `timestamp`. 19 files → 1623 unique records / 15 internal sessions / 54 human turns, all bridging the one
   cloud `session_016wViJG…`. **REDACT credentials before writing anywhere** (these transcripts held 13 real secrets —
   JWT/Stripe/Twilio/app-password); script at `Temp\build_transcript.py`. Outputs: `_berkeley-house COMPLETE transcript.md`
   - `_berkeley-house ALL PROMPTS.md`.
1. Desktop app keeps a SEPARATE session store the CLI lacks: `%APPDATA%\Roaming\Claude\claude-code-sessions\<org>\<ws>\local_<id>.json`. These are METADATA records — read `cliSessionId` + `bridgeSessionIds` from them.
2. The `cliSessionId` maps to a normal local transcript `.claude\projects\<cwd-enc>\<cliSessionId>.jsonl` (cloud-bridge sessions mirror every turn to local disk → that mirror IS the full transcript).
3. **LAST RESORT — browser scrape is unreliable.** A PURE cloud session can't be WebFetched (403); `search_session_transcripts` needs interactive approval. Driving authenticated Chrome (`get_page_text`, scroll bottom→top) works but the claude.ai renderer virtualizes + times out, so you get a PARTIAL reconstruction. The June 2026 berkeley scrape got 2 specifics WRONG that the byte-complete export later corrected (email stack was Resend+Twilio not Gmail SMTP; a "294 DB rows" detail was a misread). **Always prefer method 0/1/2; treat scrapes as provisional and reconcile against raw bytes when they arrive.**
