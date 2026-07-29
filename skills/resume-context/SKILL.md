---
name: resume-context
description: Rebuild working context for a project at the start of a session — read its vault decision log (Claude/Memory/Projects/<repo>.md) + the repo's STATUS.md + CURRENT-TASK.md, then summarize where things stand and continue. Use when the user says "/resume", "resume context", "where were we on X", or when starting work in a repo.
---

# /resume-context

Reconstruct state so you can continue without Douglas re-explaining.

## Steps

1. **Identify the repo** — cwd or named. Resolve its name via `repo-map.md`.
2. **Read, in order:** repo `CURRENT-TASK.md` (if any) → repo `STATUS.md` → vault log `<vault>/Claude/Memory/Projects/<repo-name>.md` (vault path per `CLAUDE-obsidian.md`).
3. **Reconcile:** if they disagree, trust the most recent timestamp and flag the conflict.
4. **Summarize in ≤8 lines:** goal, last state, open questions, the exact next step. Then continue the work.

## Notes

- Read via filesystem (Obsidian MCP if connected).
- If no vault log exists yet, fall back to `STATUS.md` + `git log`, and suggest running `/save-context` to start one.
