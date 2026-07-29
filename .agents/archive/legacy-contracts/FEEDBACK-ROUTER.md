# Cross-agent feedback router

Last verified: 2026-07-26

Use this contract when Douglas corrects an agent, says a mistake should never recur, or asks the harness to remember a behavior.

## Route scope and mechanisms separately

### Scope

- Path/subsystem: scoped repository rule, nested instruction, linter, or component test.
- Project: repository `AGENTS.md`, `VERIFY.md`, project skill, or project hook.
- Shared global: canonical contract or skill under `C:\Users\dougl\.agents`, projected through thin product adapters.
- Platform: Claude, Codex, or Cursor adapter, permission, hook wiring, or platform reference.
- Provider/model: evidence-backed adapter with a review trigger.
- Human-only: Setup brief, Docket card, or backlog.

### Mechanisms

Select every mechanism that addresses a distinct failure mode. The list is non-exclusive.

- Detectable unsafe action: hook or permission deny with a test.
- Missing completion evidence: `VERIFY.md` and an executable verifier.
- Repeated workflow: skill with a precise trigger.
- Project fact: `STATUS.md`, `MAP.md`, or linked memory reference.
- Active/parked work: task state or backlog.
- Stable judgment/style preference: concise rule.
- Product behavior: product adapter and verified reference.
- Rationale: Setup or Obsidian brief.

## Required decision record

Capture the incident, evidence, consequence, root-cause status, selected scope, selected mechanisms, artifact paths, verification, and review trigger. Never copy credential values or sensitive source content.

Append shared/platform/provider records to `C:\Users\dougl\.agents\feedback\FEEDBACK-LOG.md`. Append project/path records to `<repository>\.agents\feedback\FEEDBACK-LOG.md`. Use the `feedback` skill and its `Record-Feedback.ps1` helper.

Prefer the narrowest scope covering all proven occurrences. A reproduced high-cost safety, privacy, or data-loss incident may receive immediate deterministic enforcement. Promote ordinary preferences to shared global rules after cross-project evidence. Keep unresolved causes labeled as hypotheses.

For material harness changes, update the relevant Setup brief, changelog, and integrity stamp. For cloud-required corrections, update and commit the repository contract, verifier, scoped rule, or vendored skill.

Human rationale and examples: `C:\Users\dougl\.agents\human-readable\17-FEEDBACK-ROUTING-AND-CORRECTIONS.md`.
