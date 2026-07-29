# Codex Delegation Log

Running reference for how Codex jobs fail, how to recover, and a log of every incident.
Updated when a job zombies, underperforms, or produces unexpected output.

Cross-references `CLAUDE-delegation.md` (the decision rules) and `CODEX-DELEGATION-LOG.md` (this file, the operational detail).

---

## Failure Mode Taxonomy

### FM-1 — Zombie Task (status lies "running")

**Symptom:** `/codex:status` shows a job running for 30+ min. No new log lines. New dispatches block or fail.

**Root cause (from source):** `runTrackedJob` in `tracked-jobs.mjs` writes `status: "running"` and `pid: process.pid` at job start. If the worker process is killed (SIGKILL, OOM, Windows task kill) before a clean exit, the `catch` block never fires, so `status` stays "running" and `pid` is a ghost.

**Detection (run all three, in order):**

```powershell
# 1. Get the pid from state
node "$env:USERPROFILE\.claude\plugins\cache\openai-codex\codex\1.0.4\scripts\codex-companion.mjs" status <job-id> --json

# 2. Check if the PID is actually alive
tasklist /FI "PID eq <pid>" /FO CSV

# 3. Check last log write time
$log = "<logFile path from status output>"
(Get-Item $log).LastWriteTime
# If PID missing AND log >5 min stale → confirmed zombie
```

**Recovery:**

1. Note which pass the log shows it last announced (e.g., "applying fix 3 of 7") — anything after that was abandoned
2. `git diff --stat HEAD` — check for half-applied hunks; restore any partial edits with `git checkout -- <file>` if needed
3. `node codex-companion.mjs cancel <job-id>` — may print "no active job found," that's fine
4. Re-dispatch with a brief that starts from the last completed step

**Prevention:** When elapsed >20 min with no new log lines, always check PID liveness. Never trust JSON `status` alone.

---

### FM-2 — Wrapper Re-Dispatch (no work done, tokens wasted)

**Symptom:** Codex task finishes in <30 sec. Output is "Received." or "I'll get started." No file changes in `git diff`. A _new_ background task ID appears (second layer of dispatch).

**Root cause:** A Claude sub-agent received the brief and re-delegated it to Codex instead of doing work itself. The sub-agent is a meta-wrapper — it spawns another Codex job rather than executing.

**Detection:** `/codex:result` has no file-level description AND `git diff --stat HEAD` shows 0 changes.

**Recovery:** Discard the wrapped job. Do the edits directly on Claude from the main session, or dispatch Codex yourself with a concrete brief — not via a sub-agent.

**Prevention:**

- **Never use a general-purpose or Opus sub-agent to dispatch Codex.** Call `/codex:rescue` directly from the main session.
- If a sub-agent is needed for research, give it explicit write instructions ("edit file X at line N to do Y"), not "handle this with Codex."

---

### FM-3 — Wrong Brief Propagation (Codex gets placeholder prompt)

**Symptom:** Codex job completes; log shows it ran. `git diff` has no changes matching the request. The result output doesn't reference any of the files you specified.

**Root cause:** The brief was built inside a sub-agent that received an incomplete or placeholder input (e.g., prompt "test"). The actual task description was lost in the delegation chain.

**Detection:** Read `/codex:result` — if it doesn't mention the specific files or behavior from the original request, the brief was wrong.

**Recovery:** Write the Codex brief yourself in the main session. Re-dispatch with exact prompt inline (file paths, line numbers, expected diff shape).

**Prevention:**

- The brief text must appear in the main assistant message — never delegate brief-writing.
- Draft the brief, then paste it into `/codex:rescue`. Don't compose it inside a sub-agent.

---

### FM-4 — Undershoot (job stops too early)

**Symptom:** Codex completes, `git diff` shows changes, but only a subset of the requested changes was applied.

**Root cause:** Brief was ambiguous about scope, or Codex hit a verification signal (first test pass) and stopped early thinking it was done.

**Detection:** Count expected vs. actual changed files in `git diff --stat HEAD`. If actual < expected → undershoot.

**Recovery:** Resume with `--resume-last` and a diff-anchored prompt: "You stopped after X. Remaining: Y and Z. Continue without restarting X."

**Prevention:** List every file expected to change in the brief. Explicitly state: "Do not stop until all N changes are applied."

---

### FM-5 — Overshoot (scope drift, too many changes)

**Symptom:** `git diff --stat` shows many more files changed than expected. Unrelated code touched.

**Root cause:** Brief used vague scope ("improve X," "clean up Y") without explicit file bounds. Codex interpreted this as license to refactor neighbors.

**Detection:** Any file in the diff that wasn't named in the brief = overshoot.

**Recovery:** `git checkout -- <overshoot-files>` to restore them. Keep only the targeted changes.

**Prevention:** Every brief must include: "Only edit these files: [exhaustive list]. Do not touch any other file."

---

### FM-6 — Session Visibility Gap (can't see prior jobs)

**Symptom:** `/codex:status` shows no jobs even though you dispatched one earlier in the day or before a compaction.

**Root cause:** `filterJobsForCurrentSession` in `job-control.mjs` filters by `CODEX_COMPANION_SESSION_ID` env var. After a compaction or new Claude session, the ID changes. Prior jobs become invisible to the default view.

**Detection:** `node codex-companion.mjs status --all --json` — if jobs appear with `--all` but not without it, it's a session ID mismatch.

**Recovery:** Use `--all` flag or address the job by ID directly.
**Prevention:** After any compaction or session restart, always add `--all` when checking status.

---

## Brief Template

Every Codex brief must include all five components:

```
OBJECTIVE (1 sentence): Edit <file(s)> to <specific change>.

FILES (exhaustive list): Only edit: path/to/a.js, path/to/b.css. Touch no other file.

DONE WHEN: [test Y passes] OR [git diff shows exactly Z pattern] OR [behavior X occurs].

CONSTRAINTS: [API, style, pattern requirements, things to NOT change].

RESUMPTION (if resuming): Previous pass stopped after step N. Skip everything before N; start at step N+1.
```

**Do NOT include:**

- Vague directives: "improve", "clean up", "make it better"
- Open scope: "and anything else that looks related"
- Verification that requires human judgment ("make it look nicer")

---

## Verification Protocol

Run all three before declaring a Codex job complete:

```powershell
# 1. File count matches expected scope
git diff --stat HEAD

# 2. Actual diff matches the brief
git diff HEAD

# 3. Check for orphan references left by deletions
# (e.g., JS calls referencing removed DOM nodes, imports of deleted functions)
# Grep for identifiers that were removed but may still be referenced elsewhere
```

If any check fails → job is not complete. Resume or re-dispatch.

---

## 3-Minute Progress Update Protocol

For any Codex job expected >2 min:

1. Immediately after dispatch: note the job ID and what phase you expect next.
2. Use `ScheduleWakeup` with `delaySeconds: 180` to self-wake.
3. On wake: run status check → report Phase + Elapsed + last log line in chat.
4. Repeat until done. Do NOT let the user ask.

This is the only reliable mechanism — there is no persistent background timer between turns.

---

## Issue Log

| Date       | Job ID               | FM(s)      | Description                                                                                                                                                                                  | Resolution                                                                                           |
| ---------- | -------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| 2026-04-30 | task-moda8vzu-wcxypj | FM-1       | Zombie from prior session blocked new dispatch. Companion said "running"; PID was dead. `--fresh` intercepted by local guard before API call.                                                | Identified via PID check. Re-dispatched fresh from main session.                                     |
| 2026-04-30 | task-molvhl65-vwk3eo | FM-2, FM-3 | Sub-agent re-dispatched Codex with prompt "test" instead of the 7-fix explorer brief. Codex replied "Received." No file changes. Meta-wrapper consumed 29K tokens just to spawn another job. | 7 fixes done directly on Claude (Sonnet). `agent_complete` notification hook added to settings.json. |

---

## Quick Recovery Cheatsheet

| Symptom                             | First check                   | Fix                                        |
| ----------------------------------- | ----------------------------- | ------------------------------------------ |
| Status stuck "running" >20 min      | `tasklist /FI "PID eq <pid>"` | If dead → cancel + re-dispatch             |
| Job done in <30s, no diff           | `git diff --stat HEAD`        | FM-2: brief was wrapped; dispatch directly |
| Diff exists but wrong files changed | Compare diff vs brief         | FM-3 or FM-5: brief was wrong or too broad |
| Some changes missing                | Count diff vs expected        | FM-4: resume with `--resume-last`          |
| No jobs visible in status           | Add `--all` flag              | FM-6: session ID changed after compaction  |
