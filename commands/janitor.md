---
name: janitor
description: "Live system-health sweep of this machine's Claude/node/python footprint: enumerates processes (PID, age, RSS, command line), pairs Claude sessions with transcript mtime for last-activity, maps listening ports against the known-app roster (reference_local_apps.md), flags idle sessions (>5h default), memory hogs (>1GB RSS), and reparented orphans (a node/python child whose parent session has exited) in plain language, walks the parent chain to protect a live session's own helpers from being killed as false orphans, probes declared always-on services (:8756 Mission Control, :8471 Workbench) by actually connecting, and presents a kill list that executes ONLY on explicit confirmation — killing the process tree at its top (so children aren't re-orphaned and a supervisor can't respawn a killed child) with PIDs re-verified at kill time. Use when Douglas says '/janitor', 'clean up my sessions', 'what's eating memory', 'which sessions are idle', 'what's on my ports', or as a scheduled report-only daily sweep."
---

# /janitor [--kill] [--idle-hours N] [--report-only]

The manual forensics session this replaces: something feels slow, Douglas opens Task Manager and a terminal,
cross-references node PIDs against ports against half-remembered Claude sessions, and guesses which ones are
safe to kill. `janitor` runs that whole investigation as one deterministic PowerShell sweep and hands back a
table. It kills only what Douglas confirms, from PIDs it enumerated live this run.

## What this is NOT

- **Not `/doctor`.** `/doctor` audits a PROJECT's static state — files, config, wiring. `janitor` audits the
  MACHINE's live state — running processes, port bindings, service health. A project can pass doctor while
  three zombie servers fight over its port; that's janitor's territory.
- **Not `environment-preflight`.** Preflight checks one project's readiness before a run. `janitor` is
  machine-wide and runs on demand or on a schedule, with no project in scope.
- **Not a process manager.** It sweeps, reports, and (on confirmation) kills. It does no autostart wiring,
  no service installation, no restart-on-crash supervision.

## When NOT to run the kill phase (the gate)

- **An active `/longrun` or ralph watcher is running.** Its processes look idle by transcript mtime while
  deliberately waiting out a usage limit. Check for longrun/watcher state before labeling; anything backing
  an active unattended run is tagged `active long run — hands off` and excluded from the kill list.
- **A sweep that finds nothing over threshold is done.** Report "all clean" and stop. Never manufacture a
  kill candidate to look useful.
- **Scheduled mode is report-only, always.** A cron/scheduled invocation writes the table and exits; killing
  requires Douglas live in the loop (see Safety constraints).

## Steps

### 1. Enumerate processes (read-only)

`Get-CimInstance Win32_Process` filtered to `claude`, `node`, `python*` (and their `.exe` variants). For each:
PID, `ParentProcessId`, `CreationDate` → age, `WorkingSetSize` → RSS, full `CommandLine`. For Claude sessions,
pair each process with its transcript's mtime under `~/.claude/projects/**/*.jsonl` — that mtime is the
last-activity signal, since a session can sit alive for days after its last real turn.

Then resolve each process's **parent chain** (walk `ParentProcessId` up a few levels). This is what
separates a live session's helper from a true orphan — a `node`/`python` MCP server whose parent is a
*running* Claude session is doing its job (protect it); the same binary whose parent PID no longer exists has
been reparented and is the textbook orphan (a positive kill signal on its own, stronger than "matches no
roster entry"). Claude Code is a known source of these: MCP servers and Task-tool subagents spawned per
session are not tracked for cleanup, so a crashed or `/exit`-ed session leaves node/python children with a
dead parent, and they accumulate across a workday.

### 2. Map listening ports to the roster

`Get-NetTCPConnection -State Listen`, joined to the Step-1 table via `OwningProcess`. Read
`~/.claude/memory/reference_local_apps.md` for the port→app roster (currently: Mission Control :8756,
Workbench :8471, build-log's serve.py). Flag two shapes: **duplicates** (two PIDs serving one app's port —
usually a stale instance plus a fresh one) and **orphans** (a listener from a claude/node/python process that
matches no roster entry and no session Douglas recognizes).

### 3. Flag idle sessions and memory hogs — plain language

Idle: transcript mtime older than 5 hours (override with `--idle-hours N`). Hog: RSS over 1 GB. Reparented
orphan: parent PID from Step 1 no longer exists — a leftover from a session that has already exited. Every
flag gets a plain-language label a tired human can act on — "idle 9h, last touched its transcript at 03:12,
in the cad-forge folder", "node server using 2.3 GB, serving nothing", or "python MCP server whose Claude
session is gone — orphaned since 08:40" — per the standing no-jargon rule. Don't infer idle from CPU alone: a
process at 0% CPU can be blocked on I/O or a lock, not finished; the mtime/parent/roster signals decide, not
an activity snapshot.

### 4. Verify always-on services by actually connecting

For each roster app declared always-on, probe it: `Invoke-WebRequest http://127.0.0.1:<port>` with a short
timeout. A PID holding the port is a weaker signal than a served HTTP response — a wedged server passes the
first and fails the second (the post-start-probe lesson). Report each as UP (responded), WEDGED (listening,
no response), or DOWN (nothing on the port), with the restart command from the roster for anything down.

### 5. Present the kill list — kill only on confirmation

One table: PID · name · age · RSS · port/app · plain-language label · verdict (`keep` / `kill candidate` /
`ask Douglas`). Present it and STOP. On Douglas's confirmation (or `--kill` given up front, which still
requires him to confirm the specific list), kill ONLY confirmed PIDs — and immediately before each kill,
re-read that PID's command line and confirm it still matches what was enumerated, because PIDs recycle. A PID
that no longer matches is skipped and reported. Never a guessed or remembered PID (the
`feedback_background_tasks` rule).

Kill the process **tree**, not the bare PID. A Claude session (or a node/nodemon supervisor) that owns
children — MCP servers, Task subagents, shells, a PTY daemon — will, if you `Stop-Process` only its top PID,
leave those children reparented and alive: the exact orphan class this sweep exists to reclaim, recreated by
the cleanup itself. Use `taskkill /PID <pid> /T /F` (the `/T` walks and terminates descendants; Windows has no
reliable POSIX-signal path for console node/python, so the kill is forceful either way). Two consequences of
targeting the tree top: (1) it also defeats the respawn loop — killing a child under a live supervisor just
makes the supervisor spawn a replacement, so the target is always the top of the tree, never a leaf; (2)
enumerate-then-kill has a race — a supervisor can spawn a fresh child between Step 1 and the kill — and `/T`
on the parent catches children that appeared in that gap, which per-PID kills miss.

### 6. Re-probe after any kill

Re-run Steps 2 and 4: confirm freed ports are actually free and every always-on service still answers.
A kill pass without this re-probe is unverified work.

## Safety constraints (apply every run, no exceptions)

- **Read-only until explicit confirmation.** Steps 1–4 mutate nothing. `Stop-Process` runs only on PIDs
  Douglas confirmed from this run's table, each re-verified by command line at kill time.
- **Never kill:** the current session's own process tree; an active longrun/ralph watcher; any always-on
  roster service that is UP; anything whose command line is unreadable (unknown → `ask Douglas`); a
  node/python child whose parent chain (Step 1) leads to a *live* Claude session or supervisor — it is that
  session's working helper, not an orphan, even if it looks idle in isolation.
- **Kill the tree top, never a leaf.** Every kill targets the top of its process tree with `/T`, so children
  are terminated with the parent instead of reparented into new orphans, and a supervisor can't respawn a
  killed child. Scope kills to the current user's processes; never touch system or other-user PIDs.
- **No guessed PIDs, ever.** Every kill target traces to this run's live enumeration.
- **Processes only.** No service/registry/system-settings changes, no firewall edits, no autostart edits.
- **Scheduled sweeps never kill.** They write the report and exit; a kill needs Douglas responding live.
- **Verify roster claims against live state.** The roster file says where apps live and what ports they use;
  ports and paths drift, so the sweep trusts what `Get-NetTCPConnection` actually shows over what the
  roster remembers, and reports any drift it finds.

## Final report (honest register)

- **The table first** — every enumerated process with its verdict, ports mapped, services probed.
- **Flags in plain language** — what's idle, what's hogging, what's wedged, each with the one-line reason.
- **What was killed vs skipped** — per PID, including any skipped for a command-line mismatch at kill time.
- **What was verified this pass** — the re-probe results after kills; UP/WEDGED/DOWN per always-on service.
- **"All clean" is a complete answer.** A sweep with zero findings reports exactly that and stops.
- **Ambiguity goes to Douglas** — orphan listeners and unreadable processes get listed under `ask`, never
  silently killed and never silently kept without mention.
- Full absolute paths of anything written (scheduled-mode reports), per the standing Files-list convention.

---

*v1, built from the 2026-07-21 friction-mining spec (4 evidence cases). v2 (2026-07-22, `/ultraskill improve`):
added parent-chain awareness — capture `ParentProcessId`, protect a live session's children from being killed as
false orphans, flag dead-parent reparented processes as positive orphans, and kill the process tree (`/T`) at
its top so cleanup never re-orphans children or trips a supervisor respawn (evidence: Claude Code orphan-MCP
issues #15211/#22612/#33947, pnpm #12406, tree-kill, claude-gc's parent-chain protection). Remaining deepening:
richer wedge detection, per-session memory attribution, a real scheduled-task hookup.*

*Tracked copy: also save this file to `claude-global-config/commands/janitor.md` (per the skills-are-tracked
convention) after a scrub of anything machine-internal.*
