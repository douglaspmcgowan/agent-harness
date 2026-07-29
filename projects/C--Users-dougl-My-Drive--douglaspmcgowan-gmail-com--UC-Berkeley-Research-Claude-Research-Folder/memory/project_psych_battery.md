---
name: Psych_Battery / Mental Meter project
description: UC Berkeley research project — physical battery-shaped device + web app visualizing mental energy. Active repo and live URL below; details in repo CLAUDE.md.
type: project
originSessionId: aabf6e38-a7e8-4caf-bb2c-c8fc7bd99438
---

**Psych_Battery** (now also branded "Mental Meter") — a physical battery-shaped object + companion web app that visualize a user's mental energy / cognitive capacity in real time, and encourage social-connection-based recovery habits. UC Berkeley research (Expedition 3). Previously called "Pathos Battery."

**Target user:** hybrid knowledge workers using AI-powered workflows, during a typical 9–5, in-person or remote.

**Why:** the thesis is that surfacing energy rhythms externally — and making recovery visibly social — leads to more sustainable work habits and more joyful work.

## Active repos (verified 2026-05-08)

- **Frontend app:** `~/psych-battery/` — fork of `elisa-lj11/psych-battery`. Currently `feat/mental-meter-polish` branch. Active CLAUDE.md is in this repo.
- **Editorial branch parallel clone:** `~/psych-battery-editorial/` — same fork, `feat/madison-editorial` branch. Used to work both branches in parallel.
- **Backend / research hub:** `~/dpm-research-hub/` — Flask backend for the model + research synthesis hub. Live at https://dpm-research-hub.vercel.app. The `/sandbox` subpage is the Psych_Battery doc.
- **Frontend live:** https://psych-battery.vercel.app

`~/Desktop/mccomb-talks/` was a stale clone of dpm-research-hub — **deleted 2026-05-08**.

## Hardware (as of Apr 17, 2026, may be stale)

- **Good Display ESP32-L(C579) Development Kit** — includes 5.79" GDEY0579F52 4-color (BWRY) e-ink display, ESP32-L motherboard, DESPI-C579 connector board, FPC extender, USB cable. Plug-and-play, no breadboarding.
- Display specs: 150.92 × 56.94 × 1.0 mm outline, 139 × 47.74 mm active, 792 × 272 px, 12s fast / 20s full refresh.
- Communication: ESP32-L runs HTTP server; Python backend posts `/charge` with `{level: 0-100}`; ESP32 runs `drawChargeBar()` with color zones (red <20%, yellow ≥20%).
- Enclosure direction last discussed: Nalgene-1L-wide-mouth scale.
- CrowPanel firmware: always use `arduino-cli` for upload/flash (per `psych-battery/CLAUDE.md`).

## Architectural notes

- `psych-battery/index.html` is currently ~16,300 lines single-file vanilla JS with no build step. **This is no longer treated as a constraint** — splitting into `index.html` + `app.css` + `app.js` is welcome and recommended. Codex dispatches against the 16k file fail rule #5 of `feedback_codex_avoidance_rules.md` (>5k-line single-file apps), so the split also unblocks delegation.
- For pre-merge review on this repo, use `/walmart-ultrareview main...HEAD` from inside the repo (not from `Claude Research Folder/`, which isn't a git repo).
- Tech debt audit on 2026-05-04 produced `psych-battery/TECH_DEBT_AUDIT.md`; commit `8fc15b3` applied F02–F05, F09, F11. F06/F07/F08/F10 may still be open.

## Open threads

- File-split refactor (Codex job, see `Claude Code Session Audit 2026-05-06`).
- F10 (theme picker / help button overlap) likely still broken — verify in current source.
- Enclosure design (Nalgene-scale cylinder).
- Python backend for data collection: ActivityWatch + custom watchers → energy score → intervention engine. Tech Stack tab has architecture but no implementation yet.
- Intervention mechanisms: screen latency/framerate/brightness throttling, comm-tool interruption. `pynput` doesn't work reliably on macOS Sequoia — limitation to plan around.

## How to apply

When the user says "the battery," "the kit," "the build," "Mental Meter," "psych battery," "pathos battery," or the sandbox page → this is the context. Active repos above. Read `~/psych-battery/CLAUDE.md` for the live source of truth on architecture, file layout, conventions, and known bugs.
