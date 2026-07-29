---
name: project_paper_journal
description: "Mission Log (paper-journal repo) — daily voice self-recording app with mission-log UI, Whisper transcription, Obsidian vault sync, Supabase"
metadata:
  node_type: memory
  type: project
  originSessionId: ba3bab92-cb4f-4bad-9a57-827f9a5b0e5e
---

Daily voice self-recording app, "MISSION LOG". Lives at `Research Folder/paper-journal/`. (Repo/folder still named `paper-journal`; product name is Mission Log.)

**Why:** Personal daily voice journal / mission log — record, transcribe, browse, with an Obsidian vault as the durable archive.

**Stack:** Next.js 16.2.9 + React 19 + Tailwind v4 (`@import "tailwindcss"`, no config) + Turbopack (`turbopack: {}` in next.config.ts — NOT webpack). Inter + JetBrains Mono via `next/font/google`. Lucide icons (v1.x — bumped past 0.4xx; ISC). **No emoji anywhere** (Doug's hard rule for this app).

**Architecture (3 storage layers, one JournalDay model):** Supabase (cross-device sync, optional/env-gated) ⇢ IndexedDB+localStorage (always-on fallback, audio blobs survive reload) ⇢ Obsidian vault export. Key files: `src/lib/{storage,db,supabase,vault,entities,date,types}.ts`, `src/components/{JournalApp,AudioPlayer,Waveform,BrowsePanel,CalendarPopover,Gate}.tsx`, `src/workers/whisper.worker.ts`, `src/app/api/unlock/route.ts`.

**Transcription:** two-layer — Web Speech API live preview (Chrome/Edge only; sends audio to Google) + Whisper-large-v3-turbo via @huggingface/transformers in a Web Worker (WebGPU→WASM fallback) for the canonical transcript on stop.

**Obsidian vault sync:** File System Access API (desktop Chromium only; silent fallback elsewhere). Writes daily `.md` + audio into **`10_Mission Log/`** inside the **Metropolis vault**, with prev/next + on-this-day + MOC + known-entity `[[wikilinks]]`. GUARDRAIL: app only ever touches `10_Mission Log/`; never `26_Sensitive/` or `40_Reference/AI Reference.md`.

**Auth:** single passphrase gate, server-side (`APP_PASSPHRASE` env, httpOnly cookie via `/api/unlock`) — secret not in client bundle. Unset → app open. See `SUPABASE-SETUP.md` + `.env.example`. **Supabase + passphrase are NOT yet configured** (Phase 4 pending Doug's keys as of 2026-06-13).

**Live:** https://paper-journal-tawny.vercel.app  
**GitHub:** https://github.com/douglaspmcgowan/paper-journal (private, main)

**How to apply:** Next 16 has real breaking changes — read `node_modules/next/dist/docs/` before Next API code (repo AGENTS.md). `cookies()`/`headers()` are async. Mood/energy tagging was explicitly SKIPPED. `PLAN.md` in the repo has the full architecture + phase breakdown.

[[project_psych_battery]]
