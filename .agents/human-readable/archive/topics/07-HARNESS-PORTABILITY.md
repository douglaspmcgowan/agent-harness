# Harness portability status

Last verified: 2026-07-26

## Portable today

- Shared project contract through `AGENTS.md` and Claude's `@AGENTS.md` adapter.
- Stable source, data, restricted-data, worktree, and setup roots.
- Files-versus-SQLite decision policy.
- Worktree lifecycle and one-writer ownership.
- Bitwarden human/agent authority boundary.
- Gitleaks installation and repository bootstrap.
- Shared skill source library, including wrappers for all 107 Claude commands.
- Durable repository task state and Git handoffs.
- A concise shared context-loading map.
- Value-free secret and skill manifests in the project bootstrap.

## Adapters installed in this update

- Cursor global rule pointing to the shared contracts.
- Shared cross-product task-state resolver.
- Cursor session primer and task reminder using project state instead of machine-global Claude files.
- Cursor secret-exposure and destructive-command hooks emitting Cursor deny responses.
- Claude and Codex global pointers to the Setup documentation.

Synthetic integration tests confirmed that the Cursor adapters deny a direct `.env` read and a hard reset, allow `git status`, and keep a new session in the broad `General Claude` workspace from loading an unrelated root `CURRENT-TASK.md`.

The project bootstrap also passed an end-to-end disposable test covering all expected repository files, the four-directory project data layout, the Git hook, and the initial redacted Gitleaks scan.

## Product-owned

Claude keeps settings, hook wiring, plugins, sessions, auto-memory, notifications, usage behavior, and managed worktrees.

Codex keeps `config.toml`, app permissions, plugins/connectors, task storage, approvals, and managed worktrees.

Cursor keeps user rules, editor and CLI settings, hook wiring, background-agent configuration, and managed cloud isolation.

## Remaining migration track

### P0 — shared state specification

Reconcile older `.claude\state` and `.Codex\state` prose with the live `taskstate` implementation. Move all three primers, reminders, compaction guards, queue drivers, and handoff tools onto the shared resolver with product-tagged session identifiers.

### P0 — shared hook core

Move pure secret, destructive-command, protected-path, authored-document, and environment-mutation detectors into `.agents\core`. Keep tested Claude, Codex, and Cursor adapters around that core.

Cursor's current hook timing bug means its built-in permissions remain load-bearing during this migration.

### P1 — skill normalization

The 2026-07-26 audit created one evidence record per shared skill and Docket review cards. Remediation remains: resolve duplicate capability names, convert migrated full copies into compatibility aliases, repair broken references, and move product mechanics into adapters.

### P1 — generated global adapters

Generate and verify the Claude import block, Codex pointer, and Cursor user rule from shared modules. Detect drift during setup verification.

### P2 — product equivalents

Document equivalents for notifications, usage-limit waiting, long-running loops, task-board mirroring, and managed worktree creation. Preserve product-specific implementations where direct equivalence is unavailable.

## Known risks

- Cursor hooks have current vendor-reported denial timing and verdict limitations.
- Cursor state used to read global Claude files and could inject unrelated tasks; the new adapter removes that path and its broad-workspace regression test now passes.
- Several Claude/Codex hook files are duplicated manually and can drift.
- The old Claude README and MAP contain stale machine and inventory descriptions.
- Twelve capabilities have duplicate shared definitions.
- The Docket cloud board is live while the local client and daemon are absent; cards currently accumulate in a durable outbox.

Run the setup verifier and review the migration backlog before claiming full parity.

## Feedback correction routing

Future corrections use the two-axis router in brief 17: choose the proven scope, then choose the enforcement mechanism. Path and project corrections stay local to their code. Stable cross-project behavior enters the shared contract. Platform mechanics stay in product adapters. Detectable invariants use hooks, permissions, tests, or verifiers.

Cursor's feedback-scope audit reduced automatic loading from 18 rules to 10. Credential, monitoring, task-state, repository, overwrite, research-verification, and UI safety remain automatic. Eight task-triggered guidance rules now load on demand.
