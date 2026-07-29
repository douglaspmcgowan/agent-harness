# TASK.md and three-dispatcher architecture

This directory is the tested deployment candidate for consolidated task state and hooks. It leaves live product configuration and the project’s current task files unchanged until the integration pass applies it.

## Existing system reused

The implementation was derived from the live Claude, Codex, and Cursor hook configurations and their referenced scripts. The original inventory contained 39 Claude invocations, 39 Codex invocations, and 17 Cursor invocations.

Existing behavior was extended in place:

- `C:\Users\dougl\.agents\core\task-state.js` supplied project and session resolution.
- `security-checks-fast.js` supplied the composable shell checks.
- `keep-going.js` supplied continuation and R14 completion-loop semantics.
- `precompact-save-guard.js` supplied the manual-compaction guard.
- `session-primer.js` supplied startup integrity checks.
- `task-state-reminder.js` supplied prompt logging, approval surfacing, hook telemetry, skill nudges, and pathway detection.
- Cursor’s input-needed hooks supplied delayed-toast behavior.
- `Initialize-AgentProject.ps1` and `Test-AgentProjectState.ps1` supplied the project state contract.

The staged hook directory exposes exactly three executable dispatchers:

1. `security-dispatch.js` handles preflight and postflight tool events.
2. `task-state-dispatch.js` handles session, prompt, task-board, compaction, and notification events.
3. `continue-dispatch.js` is the sole Stop dispatcher.

Reusable code under `hooks\lib` runs in-process and is never wired as a hook.

## TASK.md contract

`TASK.md` holds the current goal, active work, queue, blockers, decisions, current completion evidence, and next verifier.

- `[ ]` queued
- `[~]` active
- `[x]` complete
- `[!]` externally blocked
- `[?]` needs a user decision

Required agent-created subtasks use nested checkboxes with `<!-- agent: product/session -->` provenance. Optional discoveries go to `BACKBURNER.md`. Parallel mode applies when at least three independent, file-disjoint items are eligible.

Prompt-to-task extraction stays with the agent because obligation parsing requires judgment. The prompt hook records metadata, surfaces deterministic state, and requires reconciliation.

## Migration behavior

`tools\Migrate-TaskState.ps1`:

- reads `CURRENT-TASK.md` and `WORK_QUEUE.md`;
- preserves every open, active, blocked, and decision item;
- consolidates duplicate open text, with the prior queue status taking precedence;
- copies only the current task’s completion evidence into `TASK.md`;
- retains the complete source files under `.agents\archive\task-state-migration`;
- archives `VERIFY.md` and links its retained contract from `TASK.md`;
- records the archive location once in `LOG.md`;
- removes the verified root `CURRENT-TASK.md`, `WORK_QUEUE.md`, and `VERIFY.md` files so legacy-file deployment gates clear;
- writes a deterministic result;
- returns successfully without rewriting an identical target;
- refuses to overwrite a divergent `TASK.md`.

This keeps the active ledger concise while retaining complete historical evidence in the source archive and work log.

## Dispatcher behavior

### Security

The common shell path loads the existing fast composite in-process and preserves the specialized legacy modules during migration.

Preflight security is fail-closed:

- malformed input blocks;
- an unknown preflight failure blocks;
- missing required modules block;
- corrupt or throwing required modules block;
- timed-out required modules block;
- child processes that end without a status block;
- a broken fast composite blocks when fast-composite mode is requested.

Postflight and advisory checks fail open with an explicit warning because the action already completed.

Required coverage includes:

1. visible PowerShell protection
2. secret-dump protection
3. secret-exposure decisions
4. destructive-command protection
5. environment-mutation protection
6. bulk-delete protection
7. security-config protection
8. authored-document protection
9. protected-vault protection
10. firmware protection
11. concurrent-edit protection
12. Claude dependency-audit gate

Product-specific legacy resolution checks `legacy\<product>`, the shared legacy root, the product hook directory, and the Claude hook directory in that order. `HARNESS_LEGACY_HOOKS` pins tests or deployments to one exact root.

### Task state

- Session start loads a bounded excerpt of `TASK.md`, `STATUS.md`, and the recent `LOG.md` tail.
- The next ten actionable tasks are surfaced before the excerpt.
- Startup context is capped at 24,000 characters and can be lowered with `HARNESS_STARTUP_MAX_CHARS`.
- `AGENTS.md` stays out of hook output because each product already loads its project contract.
- Prompt submit writes metadata-only telemetry: timestamp, size, hash, structural counts, skill route, and pathway flags.
- Prompt submit surfaces remaining work, approvals, hook timeouts, Stop failures, skill routes, and known skill pathways.
- Product task-board changes remind the agent to reconcile `TASK.md`.
- Manual compact after three human turns blocks once when `TASK.md` is missing.
- Auto compact proceeds.
- A second manual compact within 15 minutes overrides the guard.

### Continue

- Top-level sessions with actionable `TASK.md` items receive exit code 2 and the next item.
- Nested tasks count as actionable.
- Malformed checkbox markers require repair.
- Blocked and decision-only state allows stopping.
- Subagents and workflow stages pass through.
- Session kill switches pass through.
- Repeated unchanged work releases after three continuation checks.
- Projects awaiting migration can use the existing `keep-going.js` fallback.
- R14 completion loops run with `TASK.md`, pause on parked-only work, and clear after the exact completion token.
- Claude and Codex usage-limit waits run in-process, recognize `TASK.md`, and retain the existing long-run opt-in and stale-data safeguards.

## Parity disposition

| Previous behavior | Disposition |
|---|---|
| session-primer missing-file and wiring checks | ported to `lifecycle-diagnostics.js` |
| permission narrowing snapshot | ported |
| plugin Stop-hook rearm warning | ported |
| bounded project state injection | ported; duplicate AGENTS injection retired |
| prompt log | replaced by metadata-only prompt telemetry |
| unattended approval surfacing | ported |
| hook-timeout and Stop-failure telemetry | ported |
| skill-gap detection | ported |
| named skill-pathway detection | ported |
| task-board mirror reminder | ported for `TASK.md` |
| manual compaction guard | ported |
| R14 completion-promise loop | ported |
| Claude permission and agent-complete popups | ported through the lifecycle dispatcher |
| Cursor delayed input-needed toasts | ported across shell, MCP, response, prompt, session, and Stop events |
| Cursor Stop toast gate | absorbed into TASK-aware notification handling |
| Cursor session-size warning | retained as a product-scoped supplemental module |
| Claude usage-limit wait | ported in-process with `TASK.md` support |
| Claude green gate | retained as a product-scoped supplemental module |
| Codex usage-limit wait | ported in-process with `TASK.md` support |
| Cursor output scrubber | retained through the security dispatcher |
| product format, audit, and scheduling variants | retained through product-scoped legacy resolution |
| duplicate Codex Impeccable insertions | retired from harness wiring; the skill remains agent-invoked |

## Verification

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\dougl\projects\general-claude\harness-updates\task-hooks\tests\Run-All.ps1"
```

The suite covers:

- portable shared/product legacy resolution with `HARNESS_LEGACY_HOOKS` unset;
- every dispatcher/config legacy module, its local dependencies, and Node syntax;
- fail-closed destructive-command and secret-dump checks;
- malformed preflight input;
- missing protected-path modules;
- missing fast composites;
- corrupt, throwing, and timed-out required modules;
- fail-open advisory and postflight behavior;
- bounded startup context;
- proof that secret-shaped and ordinary raw prompt text never enters prompt telemetry;
- proof that a fresh `TASK.md` template has no actionable placeholders;
- product-config parse failures;
- nested, parked, completed, malformed, and subagent task states;
- R14 behavior with `TASK.md`;
- notification scheduling and cancellation;
- all three product JSON configurations;
- the exact three-dispatcher wiring contract;
- deterministic, concise, archived, logged, idempotent task migration that clears legacy root files.

## Live deployment gate

The staged code is safe to wire live after these prerequisites pass in the target layout:

1. Back up the live hook configurations and hook directories to a timestamped, recoverable snapshot.
2. Copy the three dispatchers and `hooks\lib` to `C:\Users\dougl\.agents\hooks`.
3. Copy required legacy security modules to the shared legacy root.
4. Keep divergent supplemental modules under `legacy\claude`, `legacy\codex`, and `legacy\cursor`.
5. Run the staged suite against the copied layout.
6. Migrate project task files and review item counts before changing wiring.
7. Apply one product configuration at a time: Cursor, Codex, then Claude.
8. Canary shell, write, read, Obsidian, prompt, task update, compact, Stop, R14, usage-limit, notification, and session-start events.
9. Move unwired scripts to the timestamped archive after the canaries.
10. Retain the archive through a nightly backup and one rollback drill.

Live deployment is unsafe when a required legacy security module is absent. The dispatcher will block the affected preflight action and name the missing module.
