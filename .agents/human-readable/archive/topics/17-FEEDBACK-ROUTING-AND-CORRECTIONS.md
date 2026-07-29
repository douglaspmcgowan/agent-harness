# Feedback routing and durable corrections

Last verified: 2026-07-26

## Goal

When Douglas corrects an agent, the harness should preserve the lesson at the narrowest reliable scope and use the strongest appropriate enforcement mechanism. A future session should receive the correction without depending on chat memory.

## The two-axis decision

Classify scope and mechanism separately.

### Scope

| Scope | Use when | Durable home |
|---|---|---|
| Path or subsystem | The behavior applies only to matching files or one component | scoped `.cursor\rules\*.mdc`, nested project instructions, linter/test configuration |
| Project | The behavior applies throughout one repository | repository `AGENTS.md`, `VERIFY.md`, project skill, project hook |
| Shared global | The behavior is stable across Douglas's projects and products | `C:\Users\dougl\.agents` canonical contract or skill, projected through product adapters |
| Platform | The behavior concerns Claude, Codex, or Cursor mechanics | that product's thin adapter, permission file, hook wiring, or product brief |
| Provider/model | Reproduced behavior requires a provider/model-specific instruction | named provider/model adapter with evidence and a review date |
| Human-only | The item is rationale, preference under consideration, or a pending decision | Setup brief, Docket card, or `BACKBURNER.md` |

Platform and breadth are independent. A Cursor rule can be project-scoped. A shared rule can require three separate product adapters.

### Enforcement mechanism

| Failure type | Preferred mechanism |
|---|---|
| Detectable unsafe action | deterministic hook or permission deny plus a test |
| Required evidence before completion | `VERIFY.md` and executable verifier |
| Repeated workflow | skill with a precise trigger |
| Project fact or current capability | `STATUS.md`, `MAP.md`, or a linked memory reference |
| Active or parked work | `CURRENT-TASK.md`, `WORK_QUEUE.md`, or `BACKBURNER.md` |
| Stable judgment/style preference | concise instruction rule |
| Product UI or permission behavior | product adapter and verified product brief |
| Human explanation and rationale | Setup or Obsidian brief |

Rules express judgment. Tests, hooks, and verifiers enforce conditions the computer can determine.

## Promotion rubric

Record the following before creating a durable correction:

1. Incident: what happened, stated without secret values.
2. Evidence: file, transcript location, test, screenshot, or reproduction.
3. Consequence: cost, safety impact, reversibility, and likely recurrence.
4. Root cause status: reproduced, supported, or still a hypothesis.
5. Candidate scope: path, project, shared, platform, provider/model, or human-only.
6. Enforcement choice: rule, skill, memory, verifier, hook, permission, or documentation.
7. Verification: the test or future scenario that proves the correction works.
8. Review trigger: date, product version change, or repeated evidence.

Promotion rules:

- A serious safety, privacy, data-loss, or high-cost incident can justify immediate deterministic enforcement after reproduction.
- A project invariant belongs in that repository after one confirmed incident.
- A general preference normally needs evidence from more than one project before entering the shared global contract.
- A platform rule requires evidence that the behavior comes from that platform's mechanics.
- A provider/model adapter requires a reproducible difference that survives prompt and task controls.
- A correction without a reproducible cause can preserve the symptom and verification requirement while labeling the cause as unresolved.

## Agent decision procedure

When Douglas says “never do that again,” “remember this,” or gives an equivalent correction:

1. Stop the failing path and answer the correction directly.
2. Preserve evidence without copying secrets or sensitive content.
3. Reproduce the failure when safe and proportionate.
4. Route it with the two-axis rubric.
5. Prefer the narrowest scope that covers all proven occurrences.
6. Prefer deterministic enforcement when the condition is machine-detectable.
7. Update the chosen live artifact and its test.
8. Update `MAP.md` when the correction introduces a new durable artifact.
9. Update the Setup brief and changelog for a material harness change.
10. Report the artifact, scope, and proof to Douglas.

If evidence supports several scopes, begin at the narrowest proven scope and add a review trigger. Promote after cross-project evidence lands.

## Avoiding global-rule bloat

The Cursor local rule audit reduced automatic loading from 18 rules to 10. The always-loaded set now carries the shared contract, monitoring, credentials, task-state continuity, list ownership, overwrite protection, repository identity, time-sensitive verification, and visual UI verification. Ten task/reference rules load on demand.

Audit each rule into one of four outcomes:

- keep globally always loaded because every session needs it;
- merge into the concise shared contract;
- convert into a triggered skill or on-demand reference;
- move into the repository or path where it applies.

An always-loaded rule should carry one stable invariant or one short routing instruction. Long explanation, examples, and evidence belong in linked references.

The audit also replaced stale `ScheduleWakeup`, `~/.config`, rollover-script, and legacy repo-map instructions with current surface-aware monitoring, Bitwarden/shared-secret routing, shared rollover, and repository-inventory guidance. Backups live under `C:\Users\dougl\.cursor\rule-backups\20260726-feedback-scope`.

## Correction record format

Use this value-free record in the project or shared feedback registry:

```yaml
id: feedback-YYYYMMDD-short-name
incident: one-sentence description
evidence:
  - path-or-test
scope: path | project | shared | platform | provider-model | human
surfaces:
  - claude
  - codex
  - cursor
mechanism: rule | skill | memory | verifier | hook | permission | brief
artifact: path
verification: command-or-scenario
status: hypothesis | reproduced | enforced | retired
reviewTrigger: date-or-version
```

The record contains no credentials, sensitive source content, or private data.

## Cloud propagation

Shared machine-global corrections do not reach cloud agents automatically. A cloud-required correction must be present in the repository contract, scoped project rule, verifier, or vendored skill and committed before dispatch.

When a shared global correction is also cloud-relevant, update the portable repository template and adopt the new managed contract block into the affected repositories.

## Live feedback implementation

Enforcement is list-valued and non-exclusive. A correction may produce a rule, skill, memory, verifier, hook, permission, test, brief, and backlog entry when each addresses a distinct recurrence path.

- Canonical skill: `C:\Users\dougl\.agents\skills\feedback\SKILL.md`
- Shared log: `C:\Users\dougl\.agents\feedback\FEEDBACK-LOG.md`
- Project log: `<repository>\.agents\feedback\FEEDBACK-LOG.md`
- Append helper: `C:\Users\dougl\.agents\skills\feedback\scripts\Record-Feedback.ps1`
- Portable rule source: `C:\Users\dougl\.agents\PORTABLE-PRINCIPLES.md`

The helper rejects credential-like values, keeps scopes and enforcement mechanisms as lists, and appends records so history remains reviewable.

## Exact action-required handoffs

The shared completion contract requires a numbered `Next steps for Douglas` checklist whenever a turn ends or work blocks with action still required from Douglas. The checklist identifies the exact location, action, named setting or field, safe value format, and confirmation to return. This prevents a technically accurate handoff from leaving Douglas to reconstruct the operational steps.

Adversarial verification cases:

| Ending state | Required behavior |
|---|---|
| Work complete and no human action remains | Omit the checklist. |
| Work complete with setup still required | Include exact numbered setup steps and the confirmation to return. |
| Goal blocked on a human-only credential or login | Name the app/page and credential field; describe the value format without exposing a value. |
| Several independent blockers remain | Preserve one ordered checklist with every action and dependency. |

## Standing sub-agent approval

Douglas has granted standing approval for sub-agent delegation. Eligible non-trivial work should use sub-agents by default when it has independent streams, would consume substantial disposable context, or a selected skill requires isolated assessment. Agents should proceed without repeating the approval prompt.

Delegation remains bounded: every task must be independently verifiable, each file has one writer unless work uses isolated worktrees, and trivial or tightly coupled work stays in the primary context. Platform-level permission rules still apply when a product cannot inherit this shared contract.
