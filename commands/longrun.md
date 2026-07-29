---
name: longrun
description: "Manage a long, unattended, perpetually-iterating run for the CURRENT project. Turning it ON auto-arms the R14 completion-promise loop (ralph), turns on waiting-out the 5-hour usage limit, AND (as of 2026-07-02) auto-starts the external watcher as a detached OS process so the run also survives the SESSION itself dying (crash/kill/limit), not just the usage-limit wait. Works for ANY project; OFF by default. Use when Douglas says 'long run', 'longrun', 'run this for hours', 'keep going past the usage limit', '/longrun', or '/longrun off'."
---

# /longrun  —  long unattended runs

Sets up the current project's session to run for a long time on its own. Today it controls the
`wait-on-usage-limit` Stop hook: when ON, an autonomous run (one with queued work in `WORK_QUEUE.<sid>.md`) that
hits the 5-hour usage limit sleeps until the window resets, then resumes. OFF by default, so normal interactive
sessions are never affected. (Renamed from the former `/autowait`.) You never hand-create control files — this
skill does it for you.

> **Scope (2026-06-29 — /longrun now auto-arms ralph).** Plain keep-going QUEUE mode force-continues at most ONCE
> per user prompt (R0 releases on `stop_hook_active`) — that alone is NOT perpetual. So turning `/longrun` ON now
> ALSO arms the R14 completion-promise loop (`.claude/ralph-loop.local.md`), which runs before R0 and continues
> THROUGH `stop_hook_active` until the agent emits the completion token (bounded by `max_iterations`). That's what
> actually drives a queue to done across many turns; `/longrun`'s own `.longrun` flag additionally covers the 5h
> usage-limit wait so a long ralph run survives the reset instead of dying. (A separate, still-unapplied patch would
> give `.longrun` its OWN bounded R0-bypass — `…/tacit-explorer/keep-going-longrun-bypass.patch.md` — but auto-arming
> ralph makes that patch non-urgent for most uses; it's gated behind the auto-mode classifier's self-modification
> check anyway.) **This does NOT extend to Task-tool subagents** — R5 explicitly passes through subagent/Workflow
> stops, so a subagent you spawn keeps going only as long as it decides to on its own, in a single agent call; there
> is no Stop-hook forcing function for it. For that, supervise it yourself (restart/resume it) or use the external
> watcher against a separate headless CLI process.

## When the environment doesn't match these assumptions (check this before arming)
Everything below assumes this machine's setup: a Windows/PowerShell shell, a resolvable `session_id`, and the
local tools (`node`, `python`, the `hook-state.js`/`longrun-watcher.py`/`longrun-preflight.js` paths). When one of
those is missing, don't improvise silently — degrade in this order and SAY which fallback you took:
- **No `session_id`** (fresh `/clear`, sandbox with none exposed) → session-scoped resolution and the ralph loop
  can't key correctly. Get one first (run one real turn so it's assigned, or read it from the SessionStart primer);
  if you truly can't, STOP and tell Douglas — do not arm with a guessed or empty id, since the queue/flag land in a
  dir the Stop hook never reads.
- **Non-Windows / non-PowerShell shell** → the `Start-Process`/`.ps1` launcher in step 5b–c is Windows-only. Keep
  the flag, queue, ralph loop, and preflight (all cross-platform); for the detached watcher, launch
  `longrun-watcher.py` with the OS's own detach (`nohup … &` / `setsid`) instead of the PowerShell block, and skip
  the endpoint-security `-WindowStyle` workaround (it's specific to this laptop).
- **Missing tool** (`node`/`python`/a script path absent, or `longrun-preflight.js` WARNs and can't be fixed) → arm
  only the parts whose tools exist and report the gap. No watcher available → fall back to the in-session usage-limit
  wait alone (say so, since the run then dies with the session). No native `claude` login → the GEN wrapper fallback
  in step 5a. Never report "armed" for a layer whose tool didn't actually run.

## Resolve the state dir CORRECTLY (read this first — the #1 footgun)
The flag + queue MUST live in the state dir that the **Stop hook** resolves for THIS session — the project the
SessionStart primer reported (e.g. `project: ai-for-cad`). The Stop hook keys off `(session_id, session cwd)`.
**Do NOT** just run `hook-state.js statedir` from your current folder: from an *unregistered subfolder* (e.g.
`frames-workbench/`) with no session id it falls to **basename isolation** (step 4 of `resolveProject`) and returns
`…/state/<that-folder-name>/` — a dir keep-going NEVER reads, so the run silently fails to keep going. (This is the
2026-06-25 failure.) Resolve it the way the hook does:
1. Find the **workspace root** = nearest ancestor with `.claude/projects.json` (here `…/Claude NASA Folder`).
2. `node "C:/Users/dmcgowa2/.claude/hooks/hook-state.js" statedir "<WORKSPACE_ROOT>"` — pass the **root** as cwd (and
   the session id as a 3rd arg if you have it) so it resolves via the session binding / registry `default`, exactly
   like the Stop hook.
3. **Sanity check:** the printed dir must end in the SessionStart-reported project (`…/taskstate/ai-for-cad`). If it ends
   in a folder name instead, you hit basename isolation — STOP and pass the root explicitly.
4. **Bind the session** so resolution is deterministic (not reliant on `default`): write
   `<root>/taskstate/sessions/<session_id>.json` = `{"project":"<id>"}`.

## Preflight FIRST (so the usage-limit wait isn't a silent no-op)
The in-session 5h wait only works if the statusLine writer (`session-usage-statusline.js`) is feeding
`usage-state.json`. Before arming a hands-off run, run the preflight and report its result:
```
node "C:/Users/dmcgowa2/.claude/tools/longrun-preflight.js"
```
- **OK** → the in-session wait is live; proceed.
- **WARN** (no statusLine wired, writer missing, or usage-state stale/`available:false`) → the in-session wait will
  NOT fire. Either fix it (wire statusLine, run one real turn so `rate_limits` appears — Pro/Max only, after the
  first API response) OR rely on the **external watcher** below for a truly hands-off run. Never walk away on a WARN
  assuming the limit will be waited out. (`available:false` right after `/clear` or before the first turn is normal;
  run a turn and re-check.)

## Turn it ON  (`/longrun [dontask|auto]`)
**2026-07-03 — the bracketed arg now selects the Claude Code PERMISSION MODE for the unattended resume, not
the old risk-posture idea.** The `auto`/`cautious` risk-posture concept documented in "Planned design" below
was never built (0% beyond a comment) and used the word `auto` for something different — a future run-behavior
axis (back up before risky actions vs. pause-and-ask), NOT the Claude Code permission mode. Until that's
actually built under different names, `/longrun`'s mode argument means permission mode: `dontask` (default —
never prompts, denies anything outside `permissions.allow`, no classifier) or `auto` (routes through Claude
Code's separate safety classifier, which can allow/block/occasionally escalate to a prompt).

1. Resolve the state dir per the section above; call it `$SD`. Bind the session (step 4 above).
2. Create empty flag `$SD/.longrun`. Write the chosen permission mode to `$SD/.longrun.permission-mode`
   (`dontask` if no arg given, else the arg).
3. **Seed the queue:** write `$SD/WORK_QUEUE.<session_id>.md` with the checklist as `- [ ]` items. `keep-going`
   drives `[ ]`/`[~]` items — but QUEUE mode alone only force-continues ONCE per prompt, so step 4 below is
   what makes the run actually perpetual.
3b. **If permission-mode is `auto`: run a pre-flight permission-planning pass BEFORE arming anything else.**
    This is a judgment call an LLM makes once, interactively, not something a hook can do:
    - Read the queue you just seeded and identify concrete action categories it's likely to hit a classifier
      block on — specific scripts/executables it'll invoke (installers, PowerShell scripts with execution-policy
      flags), process kills, anything touching `.claude/hooks/*.js` or other protected paths, unusual system
      commands. Don't guess vaguely — name the specific commands/paths where you can.
    - Present that list to Douglas (a plain enumerated list, or `AskUserQuestion` if there are real choices to
      make) and ask for a permission statement: either a blanket "yes, do these categories without asking" for
      this run, or specific `permissions.allow` rules to add now.
    - Add whatever Douglas approves as NARROW, SPECIFIC `permissions.allow` rules in settings.json immediately —
      specific patterns (`PowerShell(-ExecutionPolicy Bypass -File C:\exact\path.ps1)`, not `PowerShell(*)`) are
      the ones that actually persist through `auto` mode's classifier per current docs; a blanket pattern gets
      dropped on entry to `auto` mode and buys nothing.
    - Do this ONCE, before launching the watcher in step 5 — not mid-run. A denial that slips through anyway
      gets logged automatically (see "Behavior while armed" below) and surfaced on your next prompt regardless.
4. **Auto-arm the R14 completion-promise loop (ralph) — this is the perpetual-drive mechanism.** Write
   `<ROOT>/.claude/ralph-loop.local.md`:
   ```
   ---
   iteration: 0
   max_iterations: <N, default 40>
   session_id: <session_id>
   completion_promise: "<one-line summary of the queue's goal, e.g. 'WORK_QUEUE fully done'>"
   ---
   Work $SD/WORK_QUEUE.<session_id>.md top-down. START of every iteration, re-orient first (each resume
   arrives memoryless — Anthropic's long-running-agent harness makes this a fixed protocol): `git log
   --oneline -5` + the LOG.md tail, then RE-VERIFY the most recently `[x]`-flipped item before touching
   anything new — an iteration that died mid-verify may have claimed done falsely; if its check fails, flip
   it back to `[~]` and finish it first. Then take the first `[ ]` item (skip `[?]` parked — those need
   Douglas), mark it `[~]`, build + verify it, flip to `[x]`, **git-commit the checkpoint** with a
   descriptive message (one commit per finished item — a crash then loses at most one item's work), update
   STATUS.md/LOG.md, self-replenish the queue with the next 1-3 items if an obvious next step exists.
   **RATCHET:** never delete, skip, or weaken a test or an item's stated verify criterion to make it pass —
   a failing check means the work still has a bug to fix. Do NOT edit any file under `.claude/hooks/` — that is
   gated (self-modification of the anti-runaway Stop-hook guard is refused by the auto-mode classifier). When the
   queue has no more actionable `[ ]`/`[~]` items, emit the completion token as instructed.
   ```
   This is what keep-going's R14 rule reads: while it exists for this session, keep-going continues THROUGH
   `stop_hook_active` (before R0), bounded by `max_iterations`, until the agent wraps the per-loop nonce token in
   `<promise>` tags. Halt anytime with `/cancel-ralph` or `.stop-autorun.<sid>`. (2026-06-29: `/ralph-loop` and
   `/cancel-ralph` are now standalone commands in `~/.claude/commands/` — they do exactly this write/delete and
   work regardless of the ralph-loop PLUGIN's enabled state, which is OFF; use them instead of hand-writing the
   frontmatter every time.)
5. **Auto-start the external watcher NOW — this is what makes the run survive the SESSION itself dying (crash,
   kill, usage-limit exit, laptop sleep), not just the process staying alive.** (Added 2026-07-02 — previously
   this was a separate manual step nobody actually did.) Do this immediately, in this same turn, not later:
   0. **The watcher now refuses to double-launch itself (as of 2026-07-01) — `longrun-watcher.py` takes a
      single-instance lock (`<project-dir>/.longrun-watcher.lock.<sid>`) at startup and exits immediately
      (code 5, logged) if a watcher for the same session_id is already alive, instead of relying on the agent
      remembering to check first.** Root cause of the 2026-07-01 incident: `/longrun` (or a resumed session
      re-running it) launched the external watcher THREE separate times within ~15 minutes for the same
      session — three concurrent `gen-claude.sh --resume <sid>` CLI processes stacked on top of the
      still-alive interactive session, which is what starved the desktop app of resources until it stopped
      responding entirely. The lock is enforced in code now (unit-tested: `--self-test` covers refuse-live /
      steal-stale / release-clean), so step (c) below can't silently repeat the incident even under pressure —
      but it's still good practice to glance at `$SD/.longrun-watcher.log` / the workspace-root
      `.longrun-watcher.log` for a recent "watcher start" before launching, as a second, human-visible check.
   a. **Pick the launch command with a cheap real test, don't assume.** Try `claude -p "reply with exactly: ok"`.
      - If it prints `ok` → the native CLI works here. Read `$SD/.longrun.permission-mode` and use as `--claude-cmd`:
        - `dontask` (default): `claude --resume <sid> -p "<resume prompt>" --permission-mode dontAsk --max-turns <N, e.g. 100>`
        - `auto`: `claude --resume <sid> -p "<resume prompt>" --permission-mode auto --max-turns <N, e.g. 100>`
        (changed 2026-07-02/03 from `--permission-mode acceptEdits`, per Douglas's explicit decision — `acceptEdits`
        still routes some actions (a PowerShell exec-policy flag, a broad process kill, anything "implied but not
        named verbatim") through an interactive prompt a headless `-p` process can never answer, so the run just
        silently stalls.)
        **Why the `--max-turns` cap (added 2026-07-22).** The watcher bounds session DEATH (`--max-relaunches`) and
        a SILENT child (`--stall-timeout` kills a child whose transcript goes quiet); NEITHER bounds a single `-p`
        invocation that stays alive AND keeps advancing the transcript for hours — ralph's R14 keep-going re-injects
        through each in-process Stop, so one headless process can churn many turns unattended. That is the exact
        unbounded-intra-invocation mode every cost writeup names (a stuck agentic loop that spends without dying — the
        reported $1,800-overnight and 14k-redundant-tool-call incidents). `--max-turns` is the per-process ceiling for
        it. It composes cleanly with the watcher: hitting the cap exits NON-ZERO (verified against current headless
        docs — a `--max-turns` overflow returns a non-zero exit code), so `decide()` reads it as `clean_exit=False` and
        RELAUNCHes with fresh context (the Ralph restart pattern) instead of mis-reading it as DONE; a mid-item cutoff
        leaves the item `[~]` and the next relaunch's re-orient step (step 4) resumes it. Keep the cap GENEROUS (~100+):
        too low and you burn `--max-relaunches` on constant fresh-context restarts, each paying the prompt-cache-MISS
        rewrite the "context and cost" section below warns about. The native/subscription path is throttled by the
        usage limit this skill already waits out; the **GEN wrapper path is metered against the NASA key with no dollar
        cap**, so `--max-turns` plus a conservative ralph `max_iterations` is the only intra-run spend bound there.
        **`dontask`** never prompts — it resolves every action to allow (matches an existing `permissions.allow`
        rule) or deny, so it can't hang. It does NOT invoke the `auto`-mode safety classifier at all — there is no
        "classifier judgment + never prompts" hybrid (confirmed against current docs 2026-07-02). It also denies
        protected paths (`.claude/`, `.git/`) outright rather than checking allow rules for them. This USED to be
        an open risk for the queue files, but as of the 2026-07 relocation those live under `taskstate/<project>/`
        (NOT `.claude/`), so `dontAsk`'s protected-path denial no longer touches them; global settings.json also has
        explicit `Write/Edit(**/taskstate/**)` (plus legacy `**/.claude/state/**`) allow rules. **Still smoke-test
        before trusting it for a real unattended run:** resume a low-stakes session under `dontAsk` and confirm a
        `taskstate/**` write actually lands (check the file's mtime / new content), not just that the process
        exits 0. If the write is silently denied, fall back to `--dangerously-skip-permissions` instead (guard
        hooks still fire either way — they are a separate mechanism from the permission modes).
        **`auto`** routes every action through Claude Code's separate safety classifier — it can silently ALLOW,
        silently BLOCK (denial logged to `.classifier-denials.log` by `bypass-incident-log.js`, structured JSON),
        or after repeated blocks fall back to an interactive prompt a headless process can't answer. Step 3b's
        pre-flight planning pass exists specifically to shrink how often that fallback-to-prompt case happens by
        pre-approving narrow allow-rules for the categories most likely to get blocked.
        Your own PreToolUse/PostToolUse guard hooks — `guard-bulk-delete.js`, `check-secret-exposure.js`,
        `block-dangerous-bash.js`, etc. — fire on every matching tool call regardless of permission mode; explicit
        `deny` rules in settings.json also still apply either way.
        **Surfacing what got denied, either mode:** the watcher (launched with `--state-dir "$SD"`, see below)
        scans each check-in tick for denial-shaped output AND tails `$SD/.classifier-denials.log`, writing hits to
        `$SD/.longrun-needs-approval.<sid>.md`. `task-state-reminder.js` (UserPromptSubmit) surfaces that file's
        content at the START of your very next prompt response, then archives it — so you see it once, right
        away, without having to go check a log file yourself. Tested in isolation 2026-07-03 (8/8 unit tests
        across both the watcher's scan functions and the surfacing hook); NOT yet live-tested end-to-end against
        a real denied action during a real unattended run — treat a run with an empty needs-approval file as
        "nothing was denied, probably," not certain proof.
      - If it prints `Not logged in` (or any auth error) → this session itself is running in a sandboxed/remote
        environment with no local login (confirmed on one such environment 2026-07-01 — `ANTHROPIC_API_KEY` was
        scrubbed and there was no separate reachable OAuth session). Fall back to the GEN wrapper:
        `bash "<WORKSPACE_ROOT>/ai-for-cad/cad-forge/gen-claude.sh" --resume <sid> --model claude-sonnet-4-6 -p
        "<resume prompt>" --max-turns <N, e.g. 100>` (same per-process cap as the native path — the GEN key is
        metered, so this is the ONLY intra-run spend bound on this path) — use an ALREADY-registered model alias like `claude-sonnet-4-6`, not the newest model
        string; the newest one may 401 with `team not allowed to access model` if the GEN proxy hasn't added it
        yet. Verify with the same one-line test against `gen-claude.sh` before trusting it.
      - The `<resume prompt>` should be short and generic, and open with the same re-orientation step 4's
        loop body mandates, e.g.: "Re-orient first: `git log --oneline -5`, the LOG.md tail, and re-verify
        the last `[x]` item in WORK_QUEUE.<sid>.md (flip it back to `[~]` if its check fails). Then continue
        the queued work exactly where you left off. Keep going until the queue is genuinely empty or you hit
        a real blocker — do not stop early just because a chunk of work finished."
   b. **Write a launcher script, don't inline the command.** Bash → PowerShell → python → an embedded `-p`
      prompt is 4 layers of quoting — write `$SD/.longrun-watcher-launch.<sid>.ps1` with the full invocation as
      plain PowerShell (using `` ` `` line continuations, normal string literals), redirecting output to
      `$SD/.longrun-watcher.boot.log`. **Never embed the `-p "..."` resume prompt (or any other double-quoted,
      space-containing segment) directly in `--claude-cmd`** — found 2026-07-01: PowerShell mangles a native-command
      argument that itself contains embedded double quotes, silently splitting it into unrecognized-argument errors
      several layers down. Instead write the actual resume invocation into its OWN wrapper shell script
      (`$SD/.resume-cmd.<sid>.sh`, containing the real `--resume <sid> ... -p "<prompt>"` call) and point `--claude-cmd`
      at THAT script using only unquoted/no-space path components (prefer the absolute `bash.exe` path — it has no
      spaces — plus a path to the script RELATIVE to `--project-dir`, since `subprocess.run` already sets `cwd` to it):
      ```powershell
      & python "C:\Users\dmcgowa2\.claude\tools\longrun-watcher.py" `
        --project-dir "<WORKSPACE_ROOT>" --state-dir "$SD" `
        --claude-cmd 'C:\Users\dmcgowa2\AppData\Local\Programs\Git\usr\bin\bash.exe taskstate/<project>/.resume-cmd.<sid>.sh' `
        --session-id <sid> --max-relaunches 12 --max-stall 3 --max-wait 21600 --poll 30 `
        *> "<WORKSPACE_ROOT>\taskstate\<project>\.longrun-watcher.boot.log"
      ```
      `--state-dir "$SD"` (added 2026-07-03) is what lets the watcher tail `.classifier-denials.log` and write
      `.longrun-needs-approval.<sid>.md` into the SAME dir `task-state-reminder.js` checks — omitting it falls
      back to writing that file into the bare workspace root instead, where the surfacing hook won't find it.
   c. **Launch it fully DETACHED from this session's own process tree — never via the Bash tool's own
      `run_in_background`.** That mechanism is scoped to this session/turn and can die WITH it, which defeats
      the entire point of an external watcher. Use a real OS-level detach — but NOT `-File` and NOT
      `-WindowStyle Hidden`: found 2026-07-01 on this machine, `Start-Process powershell -WindowStyle Hidden
      -ArgumentList '-File','<script>.ps1'` gets silently killed within ~1s of launch every time (almost certainly
      endpoint security treating "hidden PowerShell running a script file" as a malware indicator — a reasonable
      thing for a NASA laptop to flag, don't try to defeat it). Invoke the launcher script via `-Command "& '<path>'"`
      instead of `-File`, and drop `-WindowStyle Hidden` (use `-WindowStyle Minimized`, or omit it — a small
      background window is an acceptable trade for the watcher actually surviving):
      `powershell -Command "Start-Process powershell -WindowStyle Minimized -ArgumentList
      '-NoProfile','-Command',\"& '$SD\.longrun-watcher-launch.<sid>.ps1'\""`
      Verify it actually survived with `Get-Process -Id <pid>` a few seconds after launch, in a SEPARATE
      command — a process that's still alive immediately after `Start-Process` returns can still be killed a moment
      later; don't trust a single instant check.
   d. **Confirm it's actually running**, don't just assume the launch succeeded: check that
      `$SD/.longrun-watcher.log` exists and shows a `watcher start:` line within a few seconds. If it doesn't
      appear, the launch failed silently — check `.longrun-watcher.boot.log` for the real error before moving on.
6. Confirm: "long run `<mode>` ON for project `<id>` — queue at `$SD/WORK_QUEUE.<sid>.md` (`<N>` open items),
   ralph armed (max_iterations=`<N>`), per-invocation cap max-turns=`<N>`, external watcher running (log at
   `$SD/.longrun-watcher.log`, launch command: native / GEN)."

## Behavior while armed — don't stop for what you can decide or route around
Two patterns Douglas explicitly wants stopped, whichever permission mode is chosen (2026-07-03):
- **A single denial (dontask deny, or an auto-mode classifier block) is not a reason to stop the whole run.**
  It's already captured automatically (`.classifier-denials.log` / the watcher's denial scan ->
  `.longrun-needs-approval.<sid>.md`, surfaced on your next prompt). Try a different approach to the SAME item
  if one exists and is safe; otherwise mark that item `[!]` in the queue and move to the next actionable one.
  Never bypass the guard that denied you (see [[feedback_verification_discipline]] / Dropped #6 in the
  2026-07-02 sweep) — "work around it" means try a different legitimate approach or skip to other work, never
  defeat the guard.
- **Don't pause to ask "this is a small fix vs. a big fix, which do you want?" while armed.** That's exactly
  the kind of judgment call an autonomous run exists to make. Default to the smaller, safer, more reversible
  option, record the choice and your reasoning as a line in `$SD/.longrun-needs-approval.<sid>.md` (so it's
  still visible on your next prompt for Douglas to override if he'd have chosen differently), and keep going.
  Only actually stop for a REAL blocker: a decision that needs information only Douglas has, or an action nothing
  in "work around it" above can substitute for (see Dropped #10's BRepNet-pickle example — a genuine security
  call belongs to Douglas, a fix-size preference does not).
- **Keep going until the queue is genuinely empty**, not until the first thing that would normally prompt for
  approval. That's the entire point of arming this in the first place.

## Turn it OFF  (`/longrun off`)
Resolve `$SD` the same way (workspace root, NOT a subfolder), then delete `$SD/.longrun` (+ `.longrun.permission-mode`) AND
`<ROOT>/.claude/ralph-loop.local.md` if it belongs to this session (check `session_id:` in its frontmatter before
deleting — never remove another session's armed loop). **Also stop the auto-started watcher** — drop
`<ROOT>/.stop-autorun.<sid>` (session-SCOPED; this is the default/normal way to turn off YOUR run). Verified live
2026-07-01: the watcher notices and stops within ~5s during its poll/relaunch sleep, and a DIFFERENT session's
watcher sharing the same workspace root is completely unaffected.

**Do NOT reach for `<ROOT>/.stop-watcher` unless you deliberately want to kill EVERY `/longrun` watcher in the
whole workspace.** Found live 2026-07-01: `.stop-watcher` is checked with NO session scoping at all
(`abort_requested()` treats it as "stop, full stop," unconditionally), and because step 5 always launches with
`--project-dir` = the WORKSPACE ROOT (not the per-project folder), that one file is shared by every project's
watcher — dropping it to turn off *your* run would silently also kill anyone else's concurrent `/longrun` in this
workspace. (Also note it must go at `<ROOT>/.stop-watcher`, never `$SD/.stop-watcher` — the per-project state
dir is not a path the watcher's `abort_requested()` ever reads.) Both sentinels get the same ~5s-during-sleep /
one-relaunch-cycle latency and the same clean, logged shutdown rather than a bare process kill. Confirm all
three (`.longrun`, `ralph-loop.local.md`, `.stop-autorun.<sid>`) are cleared.

## Verify it's actually armed (do this after turning on auto)
`node "<hook-state>" statedir "<ROOT>" "<sid>"` → confirm it equals `$SD`, and that `$SD/WORK_QUEUE.<sid>.md` exists
with open items. If the two dirs differ, the queue is misplaced and the run will stop — fix before walking away.

## Survive the limit even if the SESSION dies — the external watcher
**As of 2026-07-02 this is AUTOMATIC — step 5 of "Turn it ON" above starts this for you.** You should not need to
do anything in this section manually anymore; it's kept for reference and for the case where you want to attach a
watcher retroactively to a session that already died without `/longrun` ever having been armed on it.

The in-process wait above only works while THIS session's process stays alive. If the 5h limit kills the session, it
crashes, or the laptop sleeps, nothing resumes it without the watcher — that was the real "longrun failed
overnight" gap, and why step 5 exists. Manual invocation, if you ever need it:
```
python "C:/Users/dmcgowa2/.claude/tools/longrun-watcher.py" --project-dir "<WORKSPACE_ROOT>" --claude-cmd "claude --resume <sid> -p \"...\" --permission-mode dontAsk --max-turns 100" --session-id <sid>
```
It relaunches Claude after a usage-limit death (sleeping until `resets_at`), STOPS when the run finishes cleanly, and
STOPS+logs if the run STALLS (no transcript progress across relaunches). Guardrails: `--max-relaunches 12`,
`--max-stall 3`, `--max-wait` 6h, and a `resets_at` sanity fallback (never instant-resume into a still-limited
window). Abort any time with `.stop-autorun.<sid>` (session-scoped — prefer this one; `.stop-watcher` in the
project root also works but is UNSCOPED and stops every `/longrun` watcher sharing that root, see "Turn it OFF"
above). As of 2026-07-01 both sentinels interrupt an in-progress sleep within ~5s instead of only being checked
once the sleep finishes. Logs to `<project>/.longrun-watcher.log`. Decision logic is unit-tested (`--self-test` → 10/10), stub-integration-tested
(all 4 non-trivial outcomes: DONE/STALL/MAXRELAUNCH/ABORT), AND live-tested 2026-07-01 with a real SIGKILL + real
`--resume` recovery on a genuine session (see the vault harness doc's Rig-3 section for the full writeup).
**CAVEATS:** (1) `--claude-cmd` must be a command that actually EXITS on the limit and runs unattended — for true
hands-off use that means a headless/auto invocation (`-p` and/or `--permission-mode`), which step 5 now picks for
you (native CLI, or the GEN wrapper if the native CLI can't authenticate in this environment). The bare
`claude --continue` assumes an
interactive resume. (2) it is an auto-relaunch loop — the guardrails bound it, but treat it as such.

## Watch it live — the dashboard
`python "C:/Users/dmcgowa2/.claude/tools/longrun-dashboard.py"` starts a local, read-only HTTP dashboard at
`http://127.0.0.1:8756` (also runnable via `.claude/launch.json`'s `longrun-dashboard` config + the preview
tools). Two live-polling panels: **session transcript sizes** across every `~/.claude/projects/*/*.jsonl`,
color-flagged at 30MB/50MB against the fork-before-huge guidance below (with the exact `--fork-session`
command for each), and **active watcher logs** — tails `.longrun-watcher.log` + `.longrun-watcher.run.log` for
every root listed in `longrun-dashboard.roots.txt` (add a line there for any new project). Verified working
2026-07-02 (real data: correctly surfaced the actual 66.8MB session that triggered the finding below, plus
several older sessions past 50-100MB nobody had forked).

## A second, distinct failure mode: mid-stream stalls + huge transcripts wedging the UI (found 2026-07-02)
This is DIFFERENT from the multi-watcher-stacking incident above — it hits even a single, correctly-run
session. Confirmed real via direct transcript inspection (not just inferred): session `78cf250a-8eb4-4a5f-b5d8-
49ba19204da6` (ai-for-cad, round2-fixes branch) grew to 66,842,249 bytes and its OWN `CURRENT-TASK.md` logs, in
its own words: *"Dispatching 6 parallel subagents... hit repeated `API Error: Response stalled mid-stream` on
long-running (17-34 tool call, 300-400s+) agent turns; resuming failed subagents also failed. Only 1 of 6
survived dispatch."* A second, independent session (`a2d85704`, Claude GSFC Folder/text-to-truss) hit the
identical `Response stalled mid-stream` error via the `Workflow` tool's subagent dispatch, 5 of 7 buckets
failing identically on both a first attempt and a full independent retry. **This is a real, current,
reproducible backend limitation on long individual subagent/background turns — not something the watcher
code causes or can fix by itself.** (Two specific numbers from Douglas's report — a 2721s stall duration and
`hadFirstResponse=true` — could NOT be verified against any transcript `.jsonl` file; they likely come from the
desktop app's own internal telemetry/debug log, which isn't accessible the same way. Treat those two figures as
unconfirmed, everything else above as directly verified against real files.)

Operational mitigations (adapted from Douglas's own diagnosis, 2026-07-02 — verified consistent with the above):
- **Correction (2026-07-04, per deep-search research — this was WRONG as originally written): fork is not the
  right tool here.** `--fork-session` copies the ENTIRE accumulated context into the new session — it inherits
  the same size and, per every practitioner source found, the same per-turn cost going forward; it does not
  shrink anything. Every source on this is explicit that fork exists for exploring a DIVERGENT approach you might
  abandon (e.g. "should I redo this in GraphQL instead of REST" — fork so you don't lose the original branch),
  not for space/cost reclamation. Recommending fork-at-30MB as an anti-bloat measure conflated fork with a fresh
  restart — treat this line as retracted.
  **What to actually do once a session's `.jsonl` (visible on the dashboard above) is large or after a long
  multi-hour run:** either (a) **compact in place** if conversational continuity still matters — practitioner
  consensus is to do this proactively around ~60% context utilization, not wait for auto-compact's ~95% trigger,
  since quality degrades well before auto-compact fires — or (b) **start a genuinely FRESH session** seeded with
  a short handoff brief (goal, done steps + paths, remaining steps, exact next command) referencing durable files
  as source of truth, NOT a fork of the old one, when a clean restart is fine. A fresh session starts at whatever
  size the brief is — typically a few hundred tokens — not at the old session's accumulated size the way a fork
  does. See `Research — long-session context and cost management, 2026-07-04.md` in `Claude/Engineer/` for the
  full sourcing on this.
  **Separately, real and confirmed by Anthropic's own Claude Code team (Boris Cherny, HN 2026):** resuming (or
  forking) a session that's been idle past the prompt-cache TTL (Claude Code uses a 1-hour window for the main
  agent) triggers a full cache MISS on the next call — you pay the full expensive rewrite regardless of whether
  you fork or plain-resume, if enough idle time has passed. This is a separate cost trap from context size itself:
  don't walk away from a large session for over an hour and expect resuming it cheaply.
- **Don't queue messages while `/compact` is pending.** Wait until the input box is normal again — a queued
  message sent during a pending compact may not persist into the transcript.
- **Prefer direct main-thread execution over subagent dispatch for long synthesis turns** until the mid-stream
  stall is resolved upstream — both real sessions above independently converged on this same fallback. The
  `Workflow` tool's built-in retry is a reasonable first try; direct execution is the proven fallback.
- **Keep the repo handoff file current, not just the chat.** `CURRENT-TASK.md` (exact next command, what's
  done, verification status) is what actually survives a wedge — the transcript growing past what the desktop
  UI can tail-load is a known, real limit on this app, so treat the file as the source of truth, the chat as
  the cockpit.
- **Recover via CLI resume, not by typing into a wedged UI.** If the input box stops responding, back up the
  transcript file first, then `claude --resume <sid> --fork-session` from a terminal rather than continuing to
  type into the stuck window.

## Notes
- It only waits when there's queued work; nothing queued → the session stops normally.
- To abort a wait already sleeping: press Ctrl-C.
- Wait length is computed from the usage reset time (one sleep, no polling), clamped to the code's own `MAX_SLEEP_MS`
  ceiling (5h5m = 18300s — "a single window can't be further away than this"). The hook's `settings.json` Stop-hook
  `timeout` is deliberately larger (5h15m = 18900s, verified against the live config 2026-07-01) — it must EXCEED
  the sleep ceiling with margin, or Claude Code kills the wait before the hook can re-emit exit 2 to resume.
## Planned design — richer Long Run (spec from Douglas, 2026-06-24; only "wait out limits" is built so far)

**Capabilities**
1. **Wait out usage limits** — *built* (above).
2. **Drive a task list to done** — seed `WORK_QUEUE.<sid>.md` from a checklist Douglas gives; keep-going works it.
3. **Notify on finish / blocker** — alert when the run completes or needs input.
4. **Auto-checkpoint** — periodically save context/state (save-context / handoff) so a crash loses little.

**Two modes** — flag `.longrun.mode` = `auto` | `cautious`:
- **auto** — performs risky / outward-facing actions, but first creates a **reversal/backup** (git commit or stash,
  or a timestamped file backup) so anything risky can be undone.
- **cautious** — **pauses and asks** before any risky/outward action (git push, deploy, `rm -rf`, send email/Slack).
  If Douglas doesn't answer within **5 minutes**, Claude **emails him**.

**End condition:** stop when the task queue is empty.
**Stop controls:** both `/longrun stop` (skill verb → halts the loop) and a chat "stop the run".

**Open blockers (must resolve before building those parts):**
- *Email* needs a write-capable channel — the Gmail connector is currently **read-only** (reconnect required), or
  use an alternative (SMTP / a different connector). See [[reference_gmail_connector_permissions]].
- *The 5-min-no-response → email* escalation needs a small **background watcher** (a scheduled task), because a
  Stop/PreToolUse hook can't wait 5 minutes for a chat reply and then send mail.
