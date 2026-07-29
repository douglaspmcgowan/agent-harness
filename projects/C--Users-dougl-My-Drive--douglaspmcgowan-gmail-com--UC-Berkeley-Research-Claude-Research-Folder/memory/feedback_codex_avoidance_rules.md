---
name: When NOT to dispatch to Codex
description: Hard rules for when to skip codex:rescue and just do the work in Claude. Derived from documented failure incidents.
type: feedback
originSessionId: 24895fde-ce26-4073-baf7-26a80cb3841b
---

**Before invoking `codex:rescue` or `Skill(codex:rescue)`, check this list. If ANY of these match, do the work in Claude directly — do NOT delegate.**

1. **Sub-200-line mechanical work** (extending a test file, applying a known refactor, writing boilerplate) — Claude can do this faster than Codex's dispatch overhead.
2. **Test runs** — never delegate "run the test suite" to Codex. Use Bash directly: `node e2e/full-app.test.mjs` or whatever the project's command is.
3. **A task without a runnable verifier** (no test, no `curl`, no `lint` command Codex can use to confirm success). Without verification Codex commits based on inspection alone and silently misses regressions.
4. **>5 distinct items in one dispatch.** Later items get done shallowly or skipped silently. Split into ≤5-item dispatches.
5. **Single-file apps where the file is >5k lines** (e.g. `psych-battery/index.html` is ~14k lines). Codex spends most of its context loading the file and has nothing left for reasoning.
6. **Natural-language constraints that require semantic judgment** ("only ActivityWatch + Calendar signals"). Re-summarization degrades the constraint. If you must use Codex, write a constraint file (e.g. `SIGNALS.md`) that Codex reads as a hard spec.
7. **Parallel agents writing to the same file or sharing an output contract.** Race conditions silently break the contract. Sequential dispatch only.
8. **Writing new files with complex JS/JSON content on Windows.** PowerShell treats backtick as escape char and `$` as variable expansion — multi-line JS files with template literals, `process.env.VAR` references, or nested JSON will corrupt on every bash attempt. The session watchdog kills after ~600s of failed retries with zero file changes. Use Claude's Write tool instead — it bypasses the shell entirely. Incident 4 in CODEX-ISSUES.md.

**Why:** Four documented incidents in `C:/Users/dougl/psych-battery/CODEX-ISSUES.md`:

- UI overhaul (22 items → multiple silently skipped, signal filter broken 3+ times)
- Hardware sync (parallel agents → demo-state endpoints never wired)
- Playwright wrapper (codex-rescue exited before nested Codex job finished → 0 file changes; user ran tests manually = 127/127 PASS)
- Ingest infra on Windows (api/ingest.js with template literals → bash quoting hell → 600s watchdog → 0 file changes; Claude wrote all 4 files directly in ~8 min)

**How to apply:** When user asks for a task, run this checklist mentally BEFORE typing `Skill(codex:rescue)`. If any rule matches, just do the work in Claude. If you're unsure, default to doing it in Claude — Codex dispatch is expensive (12+ minutes typical) and frequently produces no work.

**`<status>completed</status>` from the codex-rescue wrapper does NOT mean work was done.** The wrapper exits when the dispatch is queued, not when Codex finishes. Always verify with `git diff --stat HEAD` before reporting "Codex completed the task."

**Polling protocol when a Codex job IS dispatched:** Immediately after dispatch:

1. Note the job ID from the wrapper output.
2. Call `ScheduleWakeup(delaySeconds: 180, prompt: <self-resume>, reason: "polling Codex job <id>")`.
3. On wake: read `~/.claude/plugins/data/codex-{inline,openai-codex}/state/<workspace-hash>/state.json`, find the job, report Phase + Elapsed + Status in chat.
4. If still `running`: ScheduleWakeup again at 180s and repeat.
5. If `completed`/`failed`/`cancelled`: report final status + `git diff --stat HEAD` to the user in chat.
6. If `running` but PID is dead and log >5 min stale → ZOMBIE → report and offer to cancel.

**Do NOT create Windows scheduled tasks or external watchers.** The user's preference is in-session monitoring via ScheduleWakeup. They explicitly said: "I only need that running every 3 minutes to give me updates in chat when I have long tasks running. Otherwise figure out how to monitor it yourself."

**Zombie cleanup when needed:** `MSYS_NO_PATHCONV=1 node ".../codex-companion.mjs" cancel <job-id>` — the MSYS env var prevents Git Bash from mangling the `/PID` arg in taskkill.

**For psych-battery / Mental Meter specifically:** The runnable verifier is `node e2e/full-app.test.mjs` (1200+ lines, 127 tests). The constraint contract is `STATE_CONTRACT.md`. The project lives at `C:/Users/dougl/psych-battery/`. Detailed incident log: `C:/Users/dougl/psych-battery/CODEX-ISSUES.md`.
