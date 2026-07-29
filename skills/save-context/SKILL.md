---
name: save-context
description: Checkpoint the current work session into durable memory — append a dated decision/context entry to the project's vault note (Claude/Memory/Projects/<repo>.md) and update the repo's STATUS.md. Use when the user says "/save", "save context", "checkpoint this", or before ending a work session in a code repo.
---

# /save-context

Persist what matters from this session so the next one resumes instantly. Two synced targets:

1. **Repo (self-contained):** update/create `STATUS.md` in the repo root — state, decisions, next step. (Same file `/handoff` + `session-primer` use.)
2. **Vault (cross-project memory):** append a dated entry to the project's decision log in the Obsidian vault.

## Steps

1. **Identify the repo** — cwd, or the one the user names. Resolve its canonical name + GitHub/live URL via `repo-map.md` (`<Research Folder>/repo-map.md`).
2. **Resolve the vault log** — `<vault>/Claude/Memory/Projects/<repo-name>.md` (vault path per `CLAUDE-obsidian.md`). If missing, create it from `Claude/Memory/Projects/_TEMPLATE.md` and fill the frontmatter (repo path, github, live URL).
3. **Append** a dated entry under `## Log`: what changed, decisions + **why**, open questions, the exact next step/command. Skimmable, not a transcript.
4. **Mirror** the next-step summary into the repo's `STATUS.md` so the repo stays self-contained for teammates / the other machine.
5. **Report** both paths written.

## Notes

- Write via filesystem (Obsidian MCP if connected — see `CLAUDE-obsidian.md`).
- This is the lightweight mid-work checkpoint; `/handoff` is the heavyweight end-of-session handoff. Complementary — save-context also feeds the vault so memory survives across machines via Drive.
- Capture decisions + state, not narration.
