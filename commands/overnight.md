# /overnight [goal or queue items] — arm a full unattended night run in one command

Douglas's bedtime setup, mechanized. Born from the 2026-07-21 overnight run, where arming the rig by hand
took ~25 minutes and the watcher's resume wrapper failed three environment layers deep before anyone noticed.
This command does the whole checklist in one pass and probes every layer before declaring the run armed.

## What this is NOT
- **Not `/longrun`.** `/longrun` arms the persistence rig (flag, ralph, watcher) for work already underway.
  `/overnight` is the bedtime superset: triage the goal, seed the queue, arm `/longrun`, add the heartbeat,
  dispatch recon, and leave the wake-up brief. It CALLS /longrun's steps; it does not replace them.
- **Not `/task`.** If the goal prompt is giant/multi-intent, run its decomposition first (step 1 invokes it).

## Gate
Run only when Douglas is actually stepping away ("I'm going to bed", "run overnight", "set this up and let it
run"). For a normal supervised multi-step task, seed the queue and skip the watcher/heartbeat ceremony.

## Steps
1. **Triage the goal** — if the prompt is multi-intent, apply /task's decomposition (delegate mode: assume,
   don't ask). Output: one `- [ ]` line per item.
2. **Seed the keyed queue** — resolve the state dir EXACTLY as /longrun's "Resolve the state dir CORRECTLY"
   section says (workspace root + session id through hook-state.js; verify it ends in the primer-reported
   project). Write `WORK_QUEUE.<sid>.md` with the items + an OWNER convention line ("mark [~] with OWNER
   before taking an item") so parallel workers and twin sessions never collide.
3. **Arm /longrun** — flag, permission-mode, ralph frontmatter (max_iterations 40), preflight. Follow
   longrun.md verbatim; on preflight WARN the watcher is mandatory.
4. **Write the PATH-hardened resume wrapper** — the 2026-07-21 lesson: a watcher-spawned Git bash.exe has
   NO /usr/bin, python, or shell-discovery PATH. The wrapper MUST export a complete PATH before exec:
   `/usr/bin:/bin`, Git cmd dir, `/c/Windows/System32` (+ WindowsPowerShell/v1.0), the working python dir,
   node dir, and `~/.local/bin`. Then PROBE it: run the wrapper with `PATH=""` under a 30s timeout and require
   it to reach CLI startup (no `command not found`, no shell-discovery error) before launching the watcher.
5. **Launch + verify the watcher** — per longrun.md step 5 (detached Start-Process, minimized, no -File).
   Verify: `watcher start:` line in the log within seconds AND, ~60s later, no STALL/exit line. A watcher that
   dies quietly is the failure mode this whole skill exists to prevent.
6. **Heartbeat cron** — `CronCreate` (session-only, recurring, off-minute, ~20-25 min): "check the keyed
   queue, process landed results, relaunch dead workers, take the next unowned item, finish with the wrap-up
   artifacts when done." This covers the gap where Stop hooks fail to spawn under process load and no
   background completion happens to re-wake the session (observed repeatedly 2026-07-21).
7. **Dispatch recon/workers** — background agents for the first queue items, each with: exact read paths,
   scope-guarded file ownership, the queue path, and honest [x]-only-with-proof instructions. Stagger under
   machine load (process-spawn contention is real on this laptop). For any SHELL-launched worker
   (`claude -p …`, not a Task subagent): redirect `< /dev/null` so it can't stdin-hang under nohup, and pipe
   its verbose tool output to a per-worker logfile with a tailed summary (`… > worker.log 2>&1`) so a chatty
   build can't silently blow the session's context window and halt it mid-run (Khmelinskaya's two overnight
   failure modes). A worker exiting 0 proves nothing — `claude -p` returns 0 even on a failed task; that is
   exactly why [x] needs proof, not an exit code.
8. **Leave the wake-up trail** — a vault brief (Claude/Briefs/) with: what's armed, the fleet table, handoff
   prompts for extra sessions (fresh sessions, project folders), and where the morning summary will land.
   End the chat turn with the Files list + Open items per CLAUDE.md.

## Wrap-up (the heartbeat's final firing)
When the queue is done: finalize the morning brief, run /boss-update if asked, CronDelete the heartbeat,
`/longrun off` (flag + ralph + `.stop-autorun.<sid>` — never the unscoped `.stop-watcher`), emit the ralph
completion token.

## Safety constraints
- Never edit `.claude/hooks/`; never bypass a guard that denies an action (mark [!] and move on).
- Watcher/permission mechanics defer to longrun.md — this skill never reimplements them, so fixes land once.
- Verbal broad grants get captured as scoped settings.json rules immediately.
- A night of 40 ralph iterations plus a worker fleet spends real money with no live meter. State the rough
  token/spend ceiling you expect in the brief, and set any budget guard the CLI/env exposes — an unbounded
  loop that wakes up having burned the month is the cost-side twin of the liveness failure this skill guards.
- All the usual: no pushes without authorization, backups before overwrites, secrets never printed.

## Final report — honest register
Report what is ARMED and PROBED (each layer's actual verification), the fleet, and what is merely queued.
Banned: "the run will definitely continue" — say which mechanisms are verified live and which are best-effort.

*Note: /ultraskill improve can deepen this. Tracked copy: claude-global-config/commands/overnight.md (NASA-scrubbed).*
