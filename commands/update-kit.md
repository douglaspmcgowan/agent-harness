---
name: update-kit
description: "Refresh Douglas's master agent-kit library — re-scan skills / hooks / memory / artifacts / loops / maps, regenerate kit.json, re-render the library + dashboards, and verify. Use when Douglas says 'update the kit', 'refresh the library', 'rebuild the agent kit', '/update-kit', or after adding or changing skills, hooks, memory, or artifacts."
---

# /update-kit

Refresh the self-contained agent-kit library so it reflects the current `~/.claude` + vault state.

## What it rebuilds
- The master library `<vault>/Claude/Engineer/agent-kit-library.html` (via `build-kit.js` → `kit.json`).
- The artifacts kanban (signals / tasks / decisions) embedded in it.
- Optionally the sessions board `<vault>/Claude/Engineer/sessions-board.html`.

## Steps
1. **Scan + regenerate.** Run `node "<vault>/Claude/Engineer/build-kit.js"`. It re-scans `~/.claude/commands` (skills), `~/.claude/hooks`, `~/.claude/memory` (the MEMORY.md index), the `Engineer/artifacts/` store (signals / tasks / decisions), the loop docs, and the map files; emits `kit.json`; and injects it into `agent-kit-library.html`.
2. **Sessions board (optional).** Run `node "<vault>/Claude/Engineer/build-sessions.js"` to refresh the board from `~/.claude/projects`.
3. **Verify.** Load each rebuilt HTML via the Playwright venv (`Claude Folder/_media/.venv`); confirm 0 console errors and record counts > 0 (per `VERIFY.md` → Frontend/HTML).
4. **Report** the counts (skills / hooks / memory / artifacts / loops / maps) and the FULL absolute paths of the rebuilt files.

## Constraints
- This is the PRIVATE library — it embeds the real skill/memory descriptions, some NASA-flavored, so it stays LOCAL. The PUBLIC `dpm-agent-kit` gets a SEPARATE, SANITIZED build (generic `kit.json`, no NASA), never a copy of this one.
- The 0-errors render check is the deterministic verifier; no further self-grading needed (see `VERIFY.md`).
- End with the full output paths (per `CLAUDE.md` → Surface output files).
