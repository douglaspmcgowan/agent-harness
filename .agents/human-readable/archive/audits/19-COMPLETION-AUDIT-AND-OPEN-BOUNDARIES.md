# Completion audit and open boundaries

Last verified: 2026-07-27

This audit reconciles Douglas's cross-agent harness, repository bootstrap, storage, backup, skills, Docket, feedback, secrets, and security requests against live artifacts and their verifiers.

## Verified assembled state

- Twenty-five canonical repositories live under `C:\Users\dougl\projects`; 24 pass the project baseline verifier, and `agent-harness` passes the harness verifier.
- Their managed `AGENTS.md` blocks carry portable principles, project contracts, task-state semantics, data and secret boundaries, verification rules, selected skills, and the append-only feedback mechanism.
- Claude receives each repository contract through `CLAUDE.md`; Cursor receives it through `.cursor/rules/00-shared-contract.mdc`; Codex reads `AGENTS.md`.
- The reviewed harness commits and current human-readable documentation are published. The lowercase clone at `C:\Users\dougl\projects\agent-harness` is clean and synchronized with private GitHub `master`.
- The private Docket repository exists at `https://github.com/douglaspmcgowan/docket`. The loopback-authentication repair is published at `33b00f4`.
- Docket's local SQLite store, JSON recovery exports, cloud fail-closed behavior, and local loopback trust boundary pass all 73 tests. Gitleaks reports zero findings.
- The GitHub app connector and GitHub CLI can access existing repositories. The CLI authorization is stored in the Windows keyring, and Git HTTPS uses the GitHub CLI credential helper.
- Claude skill projection resolves 50 canonical skills with zero conflicts.
- The Skills Docket contains 157 current value-free cards and archives stale generated cards. Its builder blocks concurrent writers with an exclusive outbox lock.
- Bitwarden Secrets Manager CLI and the runtime broker are installed and tested. Bitwarden's free Secrets Manager plan currently provides enough capacity for the Docket workflow: two users, three projects, three machine accounts, and unlimited secrets.
- The Docket secret manifest check passes for 12 variable names. Secret values remain outside Git and outside the manifest.
- OneDrive is no longer installed. The cleanup removed roughly 7.3 GiB of obsolete AppData runtime files; a narrowly scoped `RunOnce` cleanup will remove the shell-locked residue at the next sign-in. Replacement 168 and Berkeley worktrees now exist outside OneDrive. The old rollback copies remain because the current workspace ACL denies directory deletion.
- Google Drive for desktop is stopped. Its root-preference database confirms nine broad selected folders: `.agents`, `.claude`, `.codex`, `Data`, `Downloads`, old OneDrive Desktop/Documents, `projects`, and `Worktrees`.
- Missing personal files from old OneDrive Desktop, non-project Documents, Pictures, and Attachments have additive local copies. Existing local files were preserved and the missing-file comparison is clean.
- The canonical human-readable harness documentation is moving to `C:\Users\dougl\.agents\human-readable`; its private Git repository is the durable authority.
- BitLocker work is reference-only and has been removed from the active security backlog at Douglas's request.

## Backup decision

Use GitHub for versioned repositories and a curated local folder for value-free recovery artifacts:

`C:\Users\dougl\Documents\Agent Backups`

After Douglas removes the broad Google Drive roots, that single curated folder can be selected for Drive backup. Live repositories, worktrees, product session stores, caches, `.env` files, token stores, and live databases stay outside Drive backup. Database backups enter the curated folder only through a controlled SQLite backup or export.

## Remaining interactive boundaries

Two user-interface operations require Douglas's presence:

1. In Google Drive Preferences, remove all nine broad selected folders before restarting it. Add only curated, value-free backup exports after a restore test.
2. In Bitwarden Secrets Manager Free, create the Docket project, secret, read-only machine account, and access token. Follow `20-FREE-SECRETS-MANAGEMENT.md`. An agent can then record the value-free IDs and test Docket publication without exposing a secret value.

The old OneDrive data tree can be retired after the first boundary is complete and a fresh session opens from the lowercase project path. The current session continues to use the old path, and the workspace ACL blocks directory deletion during this session.

`C:\Users\dougl\projects\general-claude` is now a lean, bootstrapped coordination repository. The prior incomplete 4.48 GiB copy is preserved as `C:\Users\dougl\projects\general-claude-incomplete-20260727` for reversible comparison. The old workspace remains the current session's working directory.

## Source-of-truth map

- Human entry point: `C:\Users\dougl\.agents\human-readable\README.md`
- Machine-facing map: `C:\Users\dougl\.agents\HARNESS-MAP.md`
- Cross-agent rules: `C:\Users\dougl\.agents\CROSS-AGENT-CONTRACT.md`
- Repository baseline: `C:\Users\dougl\.agents\project-template`
- Setup verification: `C:\Users\dougl\.agents\human-readable\setup-stamp.json` plus `C:\Users\dougl\.agents\tools\Test-HarnessSetup.ps1`
- Harness Git authority: `C:\Users\dougl\projects\agent-harness`
- Docket Git authority: `C:\Users\dougl\projects\docket`
- Active cross-project queue: `taskstate\general claude\WORK_QUEUE.codex-cross-agent-research.md`
- Security backlog: `taskstate\general security\BACKBURNER.md`
- Docket project queue: `C:\Users\dougl\projects\docket\WORK_QUEUE.md`

The human-readable briefs preserve explanations, operating instructions, and design reasons. Live contracts, project files, skills, hooks, manifests, and verifiers supply agent behavior.
