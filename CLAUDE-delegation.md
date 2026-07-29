# Delegation rules

Default: do it yourself on Claude. Escalate across (Codex) or up (Opus
subagent) only when the criteria below are met.

## The two-question test (run before every non-trivial task)

1. **Can I write a self-contained briefing paragraph that covers
   everything the delegate needs?** If yes, delegation is on the table.
   The blocker is when distilling the brief is harder than doing the task.
2. **Is there a verification signal that doesn't require Doug's
   judgment?** Tests pass, build green, output matches schema, diff
   applies cleanly, word count met. If yes, delegate. If the only check
   is "does this look right to a human," keep it on Claude.

## Delegate to Codex (GPT-5.4 via openai/codex-plugin-cc)

**Before dispatching**, run the avoidance checklist in `memory/feedback_codex_avoidance_rules.md` (auto-loaded via MEMORY.md). Seven hard rules for when NOT to use Codex — check them first.

Use `/codex:rescue`, `/codex:review`, `/codex:adversarial-review`.
Personal tasks (email, scheduling, finances, personal writing) stay on
Claude. If it straddles both, ask first.

### Auto-delegate (just invoke, don't ask)

- First drafts of ≥200 lines of code or ≥500 words of prose, once the
  brief is agreed.
- Bulk mechanical edits across 5+ files.
- One-shot data munging scripts.
- Long-running codegen verified by tests or build.
- Same diagnosis tried twice on Claude without progress.
- 45+ min background investigations (use `--background`).
- Code review of a staged diff → `/codex:review`.
- Pre-refactor risk scan → `/codex:adversarial-review`.

### Where Codex (GPT-5.4 / 5.5) beats Opus — use Codex even if Opus is available

Opus is the chat-side reasoning ceiling, but for these specific tasks
GPT-5.4/5.5 via Codex outperforms because of training-data shape,
agentic-tool harness, and pricing:

- **Greenfield codegen from a tight brief** — Codex produces faster
  one-shot implementations of self-contained features, especially in
  TypeScript/Python/Bash. Opus burns more tokens reasoning before writing.
- **Long single-file refactors** with clear contracts (e.g. "split
  index.html into index.html + app.css + app.js, keep all behavior") —
  Codex handles the volume; Opus would either hit context limits or
  emit a partial diff.
- **Mechanical "find and rewrite" passes** — rename a function, swap an
  API, migrate a deprecated call across N files. The verifier (tests
  pass, types compile, ESLint clean) is the safety net.
- **Adversarial review of a diff** — `/codex:adversarial-review` finds
  edge cases Opus glosses over; Codex's "skeptical reviewer" persona is
  trained tighter for this.
- **Bulk format/lint/cleanup** — Prettier-able edits, ESLint
  auto-fix-style passes, JSDoc additions across many files.
- **Test scaffolding** — generating Playwright/Jest test files from an
  API contract or component spec.

For these, prefer Codex even when Opus is available. The two-question
test still applies (brief writable + verifier exists), but if both pass,
**default to Codex for code-shaped work; reserve Opus for chat-side
architectural decisions and brief-writing.**

### Where Opus still wins (don't delegate to Codex)

- **Brief writing for delegation.** The brief is the architectural
  decision; the more upstream the choice, the more Opus pays off.
- **First-pass system design** for a new project where the file list
  isn't known yet.
- **Debugging a failure that's already failed once on Sonnet** when the
  hypothesis space is wide (multiple plausible root causes). Opus will
  ask better questions.
- **Code review where the bar is "is this the right approach"** rather
  than "does this diff have bugs." Codex finds bugs; Opus questions
  premises.
- **Anything destructive without a tight verifier** — migrations,
  schema changes, credential rotations.

### Propose delegation (ask Doug first, one line)

- Lit-review summaries, related-work sections, research deep-dives.
- First-pass prose for fellowship/paper/blog sections Doug will edit
  heavily anyway.

### Keep on Claude

- Planning, spec writing, architectural decisions.
- Tasks where the brief is mushy or requirements aren't agreed.
  (Agree on the brief BEFORE delegating, never VIA delegating.)
- Iteration after a draft exists.
- Anything touching real credentials, secrets, or production deploys.
- Anything inside an autonomous `/loop`.

### Never do this

- **Do NOT use a sub-agent to dispatch Codex.** A general-purpose or Opus
  sub-agent that receives a Codex brief will re-dispatch it to Codex instead
  of doing work — producing a meta-wrapper that wastes tokens and applies no
  changes. Always call `/codex:rescue` directly from the main session.
- **Do NOT delegate brief-writing.** Write the brief yourself in the main
  assistant message; then paste it into the Codex invocation. Never compose
  the brief inside a sub-agent — the actual task description gets lost.

### Always

- Filter Codex output: "analyze each change, 95% confident before
  applying." Codex output is a proposal, not a commit.
- For first-draft delegations, state the agreed brief inline before
  invoking `/codex:rescue`. The brief must contain: (1) objective in one
  sentence, (2) exhaustive file list ("only edit X, Y, Z — no other files"),
  (3) done-when signal (test pass / diff shape / behavior), (4) constraints.
  Full template in `CODEX-DELEGATION-LOG.md § Brief Template`.
- **Progress updates (MANDATORY, not optional)**: immediately after
  every Codex dispatch, call `ScheduleWakeup(delaySeconds: 180)` — no
  exceptions. If you forget, the user will have to ask for status
  manually, which is unacceptable. Poll with
  `codex-companion.mjs status <job-id>` and report Phase + Elapsed +
  last progress line. Repeat every 3 min until done or zombie.

### Zombie-task check (codex-companion can lie about "running")

Bug: when a Codex worker process crashes mid-task, the companion
status tracker keeps it in `status: "running"` forever. Symptom: jobs
showing 30h+ elapsed in `/codex:status` are dead, not actually working.

When checking on a Codex job, never trust the JSON `status` alone.
Run all three:

1. `node ".../codex-companion.mjs" status <job-id> --json` — get the PID.
2. `tasklist //FI "PID eq <PID>"` (Windows) or `ps -p <PID>` (Mac/Linux)
   — if PID is missing, the job is dead regardless of "running" status.
3. Tail the job log for last write time. If `Get-Item ... .LastWriteTime`
   is older than 5 minutes AND PID is dead, the worker crashed.

Recovery: any edits already applied to working tree are kept, but
inspect `git diff` for half-applied hunks. The job log usually shows
which pass Codex announced last — anything announced but not in the
diff was abandoned. Cancel the zombie record (`codex-companion cancel`
may say "no job found" — that's fine, the record was auto-cleaned)
and re-spawn with a brief that resumes the abandoned pass.

Session visibility: after a compaction or new session start,
`/codex:status` only shows jobs from the current session ID. Prior
jobs become invisible. Add `--all` flag to see everything:
`node codex-companion.mjs status --all --json`.

Before declaring a Codex pass complete:

- `git diff --stat HEAD` — sanity-check the file change size matches
  the work scope.
- Grep for orphan references the deletion hunks may have left behind
  (DOM `getElementById` calls referring to removed nodes, etc.).

Detailed failure modes, recovery scripts, and the issue log:
`CODEX-DELEGATION-LOG.md`

## Escalate to Opus subagent (when the chat model is Sonnet)

Spawn via the Agent tool with `model: "opus"`. Treat Opus like Codex:
a delegation target, not a default.

### Escalate when

- The decision is load-bearing AND the brief itself is the hard part
  (so Codex won't help either).
- A previous Sonnet attempt produced plausible-but-wrong output and the
  failure looks like "didn't think hard enough," not "bad brief."
- Architectural call where a wrong guess costs >30 min of rework.

### Don't escalate for

- First drafts (that's Codex).
- Bulk edits (Codex).
- Code review (Codex).
- Routine planning/spec work (stay on Sonnet).

Announce in one line before dispatching: "Escalating to Opus subagent
because [reason]."
