---
name: handoff
description: Session handoff — hand your work cleanly to the next session: run the diagnostics .ps1, then YOU write the handoff: update CURRENT-TASK.md, promote finished items into STATUS.md, append a LOG.md line, seed/update memory, refresh the session board, and print a copy-paste resumption prompt. Invoke when the user says "handoff", "hand this off", "run session rollover", "rollover", "rollover session", "wrap up the session", "wrap this session", "close out this session", "I'm done for today", before switching projects, or before a planned context reset.
---

# /handoff

## Purpose

Hand off cleanly to the next context. The .ps1 does the deterministic diagnostics; **you** supply the rich in-flight context only you have from the conversation.

---

## Three modes — pick first

- **End-of-session handoff (rollover).** You're wrapping up; write the durable state (Phases 1–7 below) so the next session resumes cleanly. Triggers: "rollover", "wrap up", "I'm done for today", before switching projects.
- **Mid-task handoff (fork to a fresh context).** You're deep in a task, the context is degrading, but the work isn't done. Fork to a fresh session that keeps the work moving instead of pushing on in a degraded window. Triggers: "hand this off", "handoff to a fresh session", or hitting the smart-zone signal below. (See **Mid-task handoff — how**, then stop; the Phases below are the end-of-session path.)
- **Cross-platform handoff (Codex / different model family).** The work continues in a different agent harness (Codex/GPT, Gemini, etc.) that has NONE of this harness's ambient context. Do the durable-state writes (Phases 3–4) as usual, then write the self-contained handoff prompt per **Cross-platform handoff — how** below. Triggers: "handoff to codex", "handoff for gpt", "make a handoff prompt for <other agent>".

### Cross-platform handoff — how

The receiving agent reads no CLAUDE.md, no memory files, no skills, no taskstate conventions, and has different tools. Everything it needs must be **inlined or pointed at by absolute path**. Write one file, `HANDOFF-<platform>.md`, in the project root, containing:

1. **Mission + current state** — one paragraph each; what the project is, what was just finished, what's verified true right now (with the verifier command that proves it).
2. **Review map** — the files the new agent should read to review the recent work, each with a one-line "what to look for". Absolute paths. Order them: spec/vision doc → new/changed modules → their tests → produced artifacts.
3. **Remaining work** — the actual queue, one `- [ ]` per item, each with: exact entry-point command or file, definition-of-done, and the verifier. Nothing that depends on "as discussed" — each item stands alone.
4. **Ground rules distilled** — the 5–10 project/user rules the new agent would otherwise violate, inlined verbatim (e.g. gate stays sole arbiter, TDD, no "X, not Y" antithesis in prose, Files-list conventions if output goes to Douglas, DRAFT gates on outbound docs). Do NOT reference `~/.claude/*` files as authority — copy the load-bearing sentences in.
5. **Environment facts** — shell (and its syntax gotchas), Python/Node paths if nonstandard, servers to start and their ports, spaced-path quoting, anything a fresh agent hits in the first ten minutes. On this machine that's: Python 3.13 at the scoop path, spaced project roots need quoting, live_server on :8775, hooks don't exist for it (so state its safety rules explicitly: never overwrite Douglas-authored files, back up first).
6. **What NOT to do** — explicit anti-goals (don't regenerate X, don't send the DRAFT, don't commit unless asked).
7. **State-file contract** — tell it to keep updating the SAME `CURRENT-TASK.md` / `LOG.md` / `WORK_QUEUE` files (plain markdown, checkbox markers `[ ]/[~]/[x]/[!]/[?]`) so Claude sessions and the dashboard can still read the state afterward. Interop runs through these files, so the receiving agent must not invent its own state system.

Then print a short launch prompt for the other agent: "Read `<abs path>\HANDOFF-<platform>.md` fully, then <first action>." Keep the prompt tiny — the doc is the payload.

Redact secrets/keys everywhere (the doc will cross model families). Reference big artifacts by path, never inline them.

### When to hand off mid-task — the smart-zone signal
Model reasoning stays sharp only within roughly the first **~120k tokens** of a single unbroken context window (the "smart zone"). Past that you're in the "dumb zone" — the window keeps accepting tokens, but reasoning quality degrades regardless of the advertised limit. When a single unbroken reasoning phase (before a plan is locked, or mid-implementation) approaches ~120k tokens and the task isn't done, **fork via a mid-task handoff instead of pushing on degraded.** (Smart-zone/dumb-zone concept: Dex Horthy / HumanLayer, via aihero.dev.)

### `/handoff` forks; `/compact` continues
- **`/compact`** *continues* the same session with a summarized history — use it at an intentional phase break where losing verbatim history is fine.
- **`/handoff` (mid-task mode)** *forks* — a fresh session that still references the preserved context. Use it when you need genuinely clean reasoning (a fresh smart zone) that still knows what came before.

### Mid-task handoff — how
1. Write a compact handoff doc to the project folder (`HANDOFF.md`) or the OS temp dir. **Reference artifacts by path/URL — do not duplicate** what already lives in CURRENT-TASK.md, STATUS.md, specs, issues, commits, or diffs; the doc is the connective tissue that points at them. Redact any secret/PII (the summary may become a fresh agent's prompt).
2. Capture: the one-sentence goal, what's done (with paths), the exact next step, the verifier command, and any open decision.
3. Continue in a fresh context — either start a new session with the doc as the resume prompt, or dispatch a background continuation agent with the handoff summary as its brief (give it a **descriptive name** so it's findable in the job list). The fresh context inherits the work without inheriting the degraded window.

---

## Phase 1 — Gather live state (run in parallel)

```bash
git -C <cwd> status --short 2>/dev/null || echo "(not a git repo)"
git -C <cwd> branch --show-current 2>/dev/null || echo ""
git -C <cwd> log -5 --oneline 2>/dev/null || echo ""
git -C <cwd> diff --stat 2>/dev/null || echo ""
ls -la <cwd>/CURRENT-TASK.md <cwd>/STATUS.md <cwd>/LOG.md <cwd>/BACKBURNER.md 2>/dev/null || echo "(no task-state files)"
ls -la ~/.claude/BACKGROUND-TASKS.md 2>/dev/null || echo "(no global background-tasks log)"
```

From the current session, also identify:
- **In-flight files** — files edited or planned but not finished this session
- **Active background agents** — anything in BACKGROUND-TASKS.md or Codex job IDs dispatched and not reaped
- **Open decisions** — anything asked but not resolved
- **Pending verifier** — the exact command to run next session to confirm the work is intact

## Phase 2 — Run the diagnostics .ps1

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Users/dmcgowa2/bin/rollover-session.ps1"
```

**The script is diagnostics-only — it writes NOTHING.** It prints, for you to read: the CURRENT-TASK.md preview + age warning, the per-project memory dir + MEMORY.md index, files modified in the last 48 h, git status + recent log, the global `~/.claude/BACKGROUND-TASKS.md` tail, and a rollover checklist. All the actual writing (CURRENT-TASK / STATUS / LOG / memory) is **your** job in Phases 3–4.

It auto-detects the project root via `$PWD` and resolves the per-project memory dir by encoding the path under `%USERPROFILE%\.claude\projects\<encoded>\memory\`, so it works in any project. The only params are `-ProjectRoot <path>` (defaults to cwd) and `-RecentHours <N>` (defaults to 48) — there are no `-Goal/-State/-Next` params.

Read every section of the output. If the script doesn't exist, stop and tell the user — don't hand-roll the rollover unless they explicitly say "do it manually."

## Phase 3 — Write the durable handoff (CURRENT-TASK / STATUS / LOG)

The four task-state files each have one job (see `CLAUDE.md` → *Task state, backlog, status & worklog*). Keep them in the **project folder**. Use the checkbox markers everywhere: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked · `[?]` needs Douglas's decision.

**3a. CURRENT-TASK.md — active work only.** Compare the script's preview against what actually happened. If it's stale/missing and substantive work happened, **rewrite it**:

```markdown
# CURRENT-TASK.md — <one-sentence goal>

## Goal
<one sentence>

## State at rollover
- [x] <completed step> — <files changed>

## Remaining
- [ ] <next step>
- [!] <blocked step — what it's waiting on>

## Verifier
`<exact command to confirm work is intact>`

## Active background agents
- <agent ID, expected output, re-dispatch instructions if needed>

## Open decisions
- [?] <question waiting for Douglas>

## Where things live
<short pointer block — canonical paths the next session needs>
```

**3b. Promote finished items → STATUS.md.** For work that is *done* (not just paused), move it out of CURRENT-TASK into the project's `STATUS.md` (durable "what works / where it stands"). Don't leave completed items piling up in CURRENT-TASK.

**3c. Append one LOG.md line.** Add a single worklog line to the project's `LOG.md`: `YYYY-MM-DD | <what got done this session>`. Append-only — never rewrite prior lines.

**3d. Clear / park.** If the whole task is finished, clear CURRENT-TASK.md (the convention is "delete when done"). Move anything deferred-but-not-dead to `BACKBURNER.md` rather than leaving it as a dangling remaining-step.

Skip 3a entirely if the session was a one-liner or pure conversation. Rule: 5+ distinct items **or** context compaction is likely → write CURRENT-TASK. Always do 3c (the LOG line) if any real work happened.

## Phase 4 — Seed/update memory files

Walk the conversation and write entries for:

- **feedback** — every correction the user gave, *and* every non-obvious approach they confirmed worked. Include a **Why:** line and a **How to apply:** line. Save corrections AND validated approaches.
- **project** — state, deadlines, decisions, motivations — anything not derivable from current files / git log. Convert relative dates to absolute.
- **user** — new facts about the user's role, expertise, preferences. Skip if nothing new.
- **reference** — pointers to external systems (dashboards, channels, Linear projects) the user mentioned.

**Don't save:** code patterns / file paths / project structure / recent git activity / debugging fix recipes — those are derivable. Even if explicitly asked: ask what was *surprising* or *non-obvious* and save that instead.

For each new or updated memory:
1. Write the file with full frontmatter (`name`, `description`, `metadata.type`).
2. Add or update a single index line in `MEMORY.md`: `- [Title](file.md) — one-line hook`.
3. Link related memories with `[[name]]` in the body.

Update existing files rather than creating duplicates — check MEMORY.md first.

## Phase 5 — Sanity sweep

- `MEMORY.md` is index-only — no memory content directly inside it. Each line < ~150 chars. Total file < 200 lines.
- Each memory file's `description` is specific enough that future-you can decide relevance from one glance.
- `CURRENT-TASK.md` doesn't repeat content already in memory — it's *this task's* state, not durable knowledge.

## Phase 6 — Refresh the session map

Rebuild the Agent Sessions Board so the session you just closed shows up in the map:

```bash
node "C:/Users/dmcgowa2/Documents/NASA_GSFC_Vault_1/Claude/Engineer/build-sessions.js"
```

It rescans `~/.claude/projects/` transcripts, rewrites `sessions.json`, and re-injects the data into `Claude/Engineer/sessions-board.html` (the 40 most-recently-active sessions). Re-running the script IS how the board updates. Skip only if no real work happened this session.

## Phase 7 — Report + resumption prompt

Output to chat — two things, nothing else:

1. One short paragraph (max two sentences): what was rolled over — CURRENT-TASK.md updated or created? how many memory files written/updated?

2. The copy-paste resumption prompt for the next session:

```
Resume the <project name> session from CURRENT-TASK.md. Verifier: <exact command>. [Only if a Codex agent is still running: check status first via codex-companion.mjs status <id>.]
```

No headers, no bullet trees, no recap of the script output in the paragraph.

---

## When to skip

- Pure Q&A / conversation session with no file edits.
- Mid-task with plenty of context remaining — write CURRENT-TASK.md only, skip memory.
- One-liner session (single git push, npm install, etc.).
- After an unverified destructive operation — finish verification first.
- **Multi-project session** — the .ps1 is project-scoped (uses the cwd's git root) and can't summarize state across several projects in one pass. Run it once per project root, or update CURRENT-TASK.md by hand for the others.

If unsure, ask the user in one sentence: full rollover or just CURRENT-TASK update?

---

## Cross-references

- `~/bin/rollover-session.ps1` — the diagnostics script this command runs (read-only; writes nothing).
- `Claude/Engineer/build-sessions.js` → `sessions.json` → `sessions-board.html` — the Agent Sessions Board ("session map") refreshed in Phase 6. (There is no `~/.claude/sessions-map.md` on this machine — the board is the index.)
- `/save-context` — the lightweight mid-work checkpoint; this command is the heavyweight end-of-session handoff. Complementary.
- `/resume` (`resume-context`) — the start-of-session counterpart that reads STATUS.md + CURRENT-TASK.md back in.
- Memory: `reference_session_rollover.md`.
- Global: `CLAUDE.md` → `Task state, backlog, status & worklog` (the CURRENT-TASK / BACKBURNER / STATUS / LOG contract + checkbox markers).
