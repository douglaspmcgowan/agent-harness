---
name: ralph-loop
description: "Arm the R14 completion-promise loop (ralph) for THIS session — keep-going.js will continue THROUGH stop_hook_active until you emit the completion token or max_iterations is hit. Standalone command (works regardless of the ralph-loop plugin's enabled state, which is OFF — its own /ralph-loop is unreachable while disabled). Use when Douglas says 'arm ralph', 'ralph loop', '/ralph-loop', or wants a task driven to done across many turns with zero further input."
---

# /ralph-loop [goal text] [--max-iterations N]

Arms the R14 completion-promise loop that `keep-going.js` (the Stop hook) reads. While armed, a Stop event
for THIS session continues (exit 2) — even through Claude Code's own `stop_hook_active` re-entrant guard —
until the agent wraps a per-loop nonce token in `<promise>` tags, or `max_iterations` is hit. This is what
makes a session keep going with ZERO further chat input (verified live 2026-06-29 — see the vault note
"Harness loops — full reference + edge cases.md" § Testing autonomous keep-going).

## The Bash-cwd-drift trap (found live 2026-07-01 — reads as "it just stopped" with NO error)
The Bash tool's shell directory **persists across calls**. If you `cd` into a subfolder for one-off work (e.g.
building/testing a different project) and never `cd` back, every SUBSEQUENT Stop event reports that subfolder
as its cwd — and R14 looks for `<that-subfolder>/.claude/ralph-loop.local.md`, finds nothing, and silently falls
through to plain queue-mode (or allows the stop) with **zero error**. `ralph-loop.local.md`'s `iteration:` field
stops advancing but nothing tells you why — you only notice if you're specifically watching for "iteration
N/M" messages and see them replaced by ordinary queue-mode text. Diagnose it from `taskstate/<project>/.keep-going.log`:
real ralph fires log `completion-promise loop iter N`; a silently-broken one logs plain `ALLOW`/queue-mode
lines instead, with no iteration bump.
**Mitigation:** wrap any Bash command that `cd`s into a subfolder in a subshell — `(cd "subfolder" && command)`
— so the PARENT persistent shell cwd is untouched, instead of a bare `cd subfolder && command` which relocates
every later Bash call this session. If ralph seems to have stalled, check `pwd` against the workspace root
before assuming anything else is wrong.

## Resolve the file location FIRST (the #1 gotcha)
`keep-going.js`'s R14 rule reads `<cwd>/.claude/ralph-loop.local.md`, where `<cwd>` is the **Stop event's own
reported cwd** — NOT necessarily the workspace root, and NOT resolved through `hook-state.js`'s project
logic the way `WORK_QUEUE`/`STATUS`/`LOG` are. If this session was launched from the bare workspace root,
that's `<ROOT>/.claude/ralph-loop.local.md`. If launched from inside a subfolder, it's
`<that-subfolder>/.claude/ralph-loop.local.md` instead. When unsure, check what cwd your Stop-hook feedback
messages have been showing, or just use the workspace root (the common case for sessions started at the
project root).

## Arm it
Write `<cwd>/.claude/ralph-loop.local.md`:
```
---
iteration: 0
max_iterations: <N — default 20 if not given>
session_id: <this session's id>
completion_promise: "<the goal text, one line>"
---
<the full task/instructions for what "continue" means each iteration — read a queue file, build one item,
verify it, document it, self-replenish, flip it done, then stop for this turn>
```
Leave `nonce:` OUT — `keep-going.js` auto-generates one on first fire and injects it into the stderr message
it prints (never into a copy-pasteable form beforehand), so the completion token can't be echoed back
falsely. Do not hand-write a nonce.

**Check for a competing armed loop first.** Only one `ralph-loop.local.md` can be active per cwd. If one
already exists for a DIFFERENT purpose/session, either wait for it to finish, choose a different goal that
reuses it, or (if truly abandoning the old one) overwrite it deliberately and say so.

**Before relying on it, sanity-check the wiring once** (this consumes iteration 1, so say so if you do it):
```
echo '{"session_id":"<sid>","cwd":"<cwd>","transcript_path":"<anything>","stop_hook_active":false}' | \
  node C:/Users/dmcgowa2/.claude/hooks/keep-going.js
```
Expect exit code 2 and "completion-promise loop, iteration 1/<N>" with your goal text. If instead you get
exit 0 with "`.stop-autorun`/`.need-user`/`.no-keepgoing` present" — R3 sentinels are checked BEFORE R14 and
will block it entirely; clear the sentinel for this (project, session) first (see `taskstate/<project>/`).

## Confirm to the user
"Ralph armed for this session — max_iterations=<N>, goal: <one line>. It'll fire as 'Stop hook feedback'
after this turn ends, with no further input needed. Halt anytime with `/cancel-ralph` or a
`.stop-autorun.<sid>` sentinel."

## Running it in a genuinely separate project concurrently with other autonomous work
Only one `ralph-loop.local.md` exists per cwd, so if another mechanism (a monitored subagent, another
session) is already autonomously driving files in this SAME workspace, either: (a) point THIS ralph goal at
files that mechanism never touches (a different project folder — see the tacit-explorer / tacit-prior-art
split, 2026-06-29), or (b) don't arm a second one. A `.stop-autorun.<sid>` sentinel in the OTHER project's
state dir is a clean way to pause its own queue-mode drive without touching ralph's file at all.
