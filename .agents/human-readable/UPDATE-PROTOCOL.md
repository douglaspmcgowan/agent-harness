# Harness update protocol

Last verified: 2026-07-29

Every material harness change follows this sequence:

1. Seed or update the active `TASK.md`.
2. State the intended invariant and affected products.
3. Read current vendor documentation for product behavior that may have changed.
4. Back up every existing file that will be replaced.
5. Modify the shared core or product-owned adapter at the narrowest correct layer.
6. Add or update a deterministic test for the behavior.
7. Test safe cases, blocked cases, malformed input, wrong directories, and concurrent-session boundaries.
8. Run the full assembled product path when possible.
9. Update the single human guide when the human-facing system changed.
10. Update global or project `MAP.md`, skill/Docket contracts, and project templates when loading behavior changes.
11. Add a dated entry to `CHANGELOG.md`.
12. Run `Manage-Harness.ps1 -Action Stamp`.
13. Run `Manage-Harness.ps1 -Action VerifyGlobal`, the staged hook suite, and each affected project verifier.
14. Record remaining product limitations and any manual restart check.

## Documentation rule

`human-readable\README.md` explains the live system. A harness change remains incomplete while the guide, changelog, or canonical integrity stamp describes an older state.

## Backups

Backups of live harness files go under:

```text
C:\Users\dougl\.agents\backups\<timestamp>\
```

Product-owned files may use the product's existing backup convention. Never place credentials, sessions, tokens, or vault exports in the setup backup.

## Verification levels

- Static: syntax, JSON/TOML parsing, path and import checks.
- Unit: synthetic allow/block payloads and task-state fixtures.
- Integration: actual executable, Git hook, CLI, or product hook runner.
- Adversarial: malformed inputs, broad paths, secret-shaped fixtures, concurrent worktrees, and rollback/drift checks.
- Human UI: settings, account, encryption, recovery, connector, and restart checks that require Douglas.
