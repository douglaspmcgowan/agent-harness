# Shared skill audit results

Verified: 2026-07-26

## Coverage

The audit reconciled every discovered `SKILL.md` under `C:\Users\dougl\.agents\skills`:

| Measure | Count |
|---|---:|
| Skill definitions | 157 |
| Unique source paths | 157 |
| Docket cards generated | 157 |
| Portable | 26 |
| Adapter needed | 118 |
| Product owned | 13 |
| Broken | 0 |
| High severity | 18 |
| Medium severity | 120 |
| Low severity | 13 |
| No material finding | 6 |

The 157 definitions include 156 top-level packages and one nested compatibility pointer. Duplicate frontmatter names use catalog-qualified identities in the Docket.

## Main portfolio findings

1. The four broken pointers/resources found in the first pass are repaired and re-audited.
2. Presentation and frontend-design families contain overlapping triggers and duplicated guidance.
3. Many migrated command skills still contain Claude vocabulary, device-local paths, model names, or POSIX shell examples.
4. Nineteen skill bodies exceed the 500-line progressive-disclosure target.
5. Several audit or maintenance workflows combine diagnosis and mutation and need clearer write gates.
6. Task/context lifecycle guidance appears in several skills and should route to the shared task-state contract.
7. The `skill-audit` skill now defines the reusable evidence schema, portability classes, and Docket workflow.

## Recommended review order

1. Broken pointers and missing resources.
2. High-severity write, secret, and authority findings.
3. Presentation-family ownership.
4. Design-family ownership.
5. Task/context lifecycle consolidation.
6. Windows shell and machine-path adapters.
7. Frontmatter normalization and progressive disclosure.
8. Provider and model adapter extraction.

## Permanent dirty-file model

A repository is dirty when tracked files differ from the checked-in commit or untracked files are present. The current Codex global-config checkout intentionally carries a local `AGENTS.md` modification and additive machine files, so `git status` always reports changes.

That arrangement weakens the status signal: expected divergence and accidental edits appear together. Treat it as transitional. The durable replacement is a divergence manifest containing each permitted path, owner, reason, validation rule or expected hash, and review date. Sync health then fails any undeclared dirty path and any declared path whose evidence changed unexpectedly.

## Evidence and review state

The durable audit JSONL and summaries live under:

```text
C:\Users\dougl\Data\Projects\agent-harness\audits\2026-07-26\
```

The value-free Docket outbox lives under:

```text
C:\Users\dougl\Data\Projects\agent-harness\docket-outbox\skills-audit\
```

Each card is grouped by portability class and severity. The reviewed local client is restored. Cloud publication requires the Docket review credential, which is absent from the current environment.

The final 157-card set is also imported into Docket’s local SQLite store. The loopback UI is verified at `http://127.0.0.1:8471/` when the local server is running.
