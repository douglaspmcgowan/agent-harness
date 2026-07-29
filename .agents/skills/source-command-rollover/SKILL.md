---
name: "source-command-rollover"
description: "End-of-session rollover — capture live git context, reconcile TASK.md, seed memory files, and print a resumption prompt. Invoke when the user says \"run session rollover\", \"rollover\", \"wrap up the session\", or equivalent."
---

# source-command-rollover

Use this skill when the user asks to run the migrated source command `rollover`.

## Command Template

# /rollover

## Purpose

Hand off cleanly to the next session. Capture live state first; then you do the writing — because only you have the conversation context.

---

## Phase 0 — Capture live state

Run in parallel (skip git commands if the project isn't a git repo):

```bash
git -C <cwd> status --short
git -C <cwd> branch --show-current
git -C <cwd> log -5 --oneline
git -C <cwd> diff --stat
```

From the current session, also identify:

- **In-flight files** — files edited or planned but not finished
- **Active background agents** — any Codex job ID dispatched and not yet reaped
- **Open decisions** — anything asked of the user but not resolved
- **Pending verifier** — exact command to run next (`npm test`, `node e2e/...`, etc.)

## Phase 1 — Run diagnostics script (if it exists)

```powershell
~/bin/rollover-session.ps1
```

If the script exists, run it and read every section it prints (TASK.md preview, memory dir, files modified in last 48 h, git status, checklist).

If the script doesn't exist, skip this phase — do everything inline in the phases below. Do **not** stop and wait for the user; the script is optional.

## Phase 2 — Reconcile `TASK.md`

Compare what actually happened this session against `TASK.md`. Preserve its existing queue and reconcile these canonical sections:

1. **Goal** — keep the active task chain accurate.
2. **Active / Queue** — update current work and ordered follow-ups.
3. **Blocked / Needs decision** — record unresolved dependencies and user decisions.
4. **Completed** — move only work with concrete evidence.
5. **Verification** — record the exact next command or observable proof.

Skip `TASK.md` updates for a one-liner or pure Q&A with no file edits. Keep all active state and verification evidence in `TASK.md`.

## Phase 3 — Seed/update memory files

Use the auto-memory rules from `~/.Codex/AGENTS.md`. Walk the conversation and write entries for:

- **feedback** — every correction the user gave, _and_ every non-obvious approach they confirmed worked. Include a **Why:** line and a **How to apply:** line. Save corrections AND validated approaches; one-sided memory drifts.
- **project** — state, deadlines, decisions, motivations behind work — anything not derivable from current files / git log. Convert relative dates to absolute.
- **user** — new facts about the user's role, expertise, preferences. Skip if nothing new.
- **reference** — pointers to external systems (Linear projects, dashboards, channels) the user mentioned.

**Don't save:** code patterns / file paths / project structure / recent git activity / debugging fix recipes — those are derivable. The exclusion applies even if the user explicitly asks: ask what was _surprising_ or _non-obvious_ and save that instead.

For each new memory:

1. Write the file with full frontmatter (`name`, `description`, `metadata.type`).
2. Add a single index line to `MEMORY.md`: `- [Title](file.md) — one-line hook`.
3. Link related memories with `[[name]]` in the body — bidirectional when both exist.

If a memory file already covers the topic, **update it** rather than creating a duplicate.

## Phase 4 — Sanity sweep

- `MEMORY.md` is index-only — no memory content directly inside it. Each line < ~150 chars. Total file < 200 lines (lines after that get truncated).
- Each memory file's `description` is specific enough that future-you can decide relevance from one glance.
- `TASK.md` keeps active state and verification evidence concise; durable knowledge stays in its canonical project file.

## Phase 5 — Print resumption prompt

Print the following for the user to copy-paste into the next session:

```
Resume the <project name> session from TASK.md. Verifier: <exact command>. [If a background agent is still running: check its status first via <reap command>.]
```

## Phase 6 — Report back

One short paragraph, max two sentences:

1. What was rolled over (`TASK.md` updated? new memory files? counts).
2. What's open or what verifier to run next session.

No headers, no bullet trees, no recap of the script output or phase list.

---

## When to skip

- Pure conversation / Q&A session with no file edits.
- The user is mid-task and asked to pause — update `TASK.md` only and skip memory.
- The user is running a one-liner — `git push`, `npm install`, etc. — no rollover needed.

If unsure, ask the user in one sentence whether to do a full rollover or a `TASK.md` update.

---

## Cross-references

- `~/bin/rollover-session.ps1` — optional diagnostics script; if missing, all phases still run inline. Create at `C:\Users\dougl\bin\rollover-session.ps1` when ready.
- `~/.Codex/sessions-map.md` — sessions index (written by the .ps1 when it exists)
- Memory: `feedback_durable_state_before_compaction.md`, `feedback_long_prompt_discipline.md`
- Global: AGENTS.md `Task state` section
