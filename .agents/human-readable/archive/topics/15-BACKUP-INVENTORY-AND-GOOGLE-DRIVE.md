# Data, backup inventory, and Google Drive

Last consolidated: 2026-07-29

This guide consolidates the former storage/SQLite and Google Drive status briefs. Their dated source text remains under [`archive/topics`](archive/topics/).

## Storage model

- Source code, schemas, migrations, safe fixtures, and value-free manifests live in Git.
- Mutable project application data lives under `C:\Users\dougl\Data\Projects\<project>`.
- Restricted data lives under `C:\Users\dougl\Data\Restricted\<project>` and requires a project-specific privacy and recovery plan.
- Plain files suit documents, media, immutable inputs, portable exports, and append-only logs.
- SQLite suits transactions, relationships, integrity constraints, indexed queries, and coordinated multi-record updates.
- Live SQLite databases, write-ahead logs, credentials, real personal records, large corpora, and generated output archives stay outside Git.

SQLite backups use the database backup mechanism so the snapshot is transactionally consistent. Critical records also receive periodic portable exports when the project requires them.

## Authorities and locations

| Material | Live location | Backup authority |
|---|---|---|
| Shared agent harness | `C:\Users\dougl\.agents` | `https://github.com/ai-consulting-1/doug-harness.git` |
| Human harness documentation | `C:\Users\dougl\.agents\human-readable` | Same private harness repository |
| Stable source repositories | `C:\Users\dougl\projects\<project>` | Each repository's GitHub remote |
| Docket source | `C:\Users\dougl\projects\docket` | `https://github.com/douglaspmcgowan/docket.git` |
| Docket runtime database | `C:\Users\dougl\.docket-local\docket.sqlite3` | Transactionally consistent snapshot under `C:\Users\dougl\Documents\Agent Backups` |
| Project application data | `C:\Users\dougl\Data\Projects\<project>` | Approved per-project snapshot/export |
| Restricted project data | `C:\Users\dougl\Data\Restricted` | Project-specific encrypted/offsite plan after privacy review |
| Worktrees | `C:\Users\dougl\Worktrees` | Git commits and branches |
| Product sessions/caches/auth state | `.claude`, `.codex`, `.cursor` | Product sync/export where supported; excluded from broad file sync |

## Google Drive decision

Google Drive remains Douglas's current offsite copy. The portable agent recovery route uses the curated `My Drive\Capsule` folder plus the explicitly selected `Agent Backups` route. Desktop, Documents, and Downloads are broader personal-file backup choices; they are outside the harness's required recovery surface.

The current cleanup gate is to remove the broad Desktop, Documents, and Downloads computer-backup selections after their uploads and local copies are confirmed. Keep `My Drive\Capsule` and the deliberate Agent Backups route. This prevents duplicate or accidental syncing of live engineering state.

Keep these live engineering and product-state roots out of Google Drive "Folders from your computer":

- `C:\Users\dougl\.agents`
- `C:\Users\dougl\.claude`
- `C:\Users\dougl\.codex`
- `C:\Users\dougl\.cursor`
- `C:\Users\dougl\Data`
- `C:\Users\dougl\projects`
- `C:\Users\dougl\Worktrees`
- `C:\Users\dougl\OneDrive`
- `C:\Users\dougl\Tools`

Douglas updated Google Drive's folder selection and reported the client **Up to date** on 2026-07-27. The selected roots still require a current Preferences check before the broad-root cleanup is recorded as complete.

Google Drive synchronizes these selected folders continuously while the desktop client is running, signed in, online, and unpaused. Changes do not wait for a daily backup window.

## What goes into Agent Backups

- the value-free harness recovery pointer;
- a generated, Gitleaks-clean machine setup manifest;
- consistent SQLite backups produced through SQLite's backup mechanism;
- project inputs and outputs approved by each project's data manifest;
- sanitized snapshots of valuable uncommitted work when Git is temporarily unavailable;
- restore-test records.

The `Nightly Agent Backups` scheduled task is registered as **Ready** with a daily 02:00 trigger. Its former settings could refuse or stop a run during battery use and did not catch up a missed start. The portable installer now enables start-when-available, permits battery operation, avoids stopping on a battery transition, preserves the limited interactive account, and applies a six-hour ceiling.

The first 2026-07-29 assembled proof run was intentionally stopped after it materially worsened an active 97%-memory-pressure incident. A later run completed successfully and advanced `Recovery\latest.json` to snapshot `20260729-002722`. The repaired task registration and the new snapshot both passed the assembled harness checks.

When `Backup-AgentWorkspace.ps1` completes successfully, it writes a timestamped, Gitleaks-clean snapshot under `Documents\Agent Backups\Workspace`. The snapshot includes offline bundles for every repository with a commit, reviewed dirty-work snapshots, per-project handoffs, approved `Data\Projects` material, consistent SQLite backups, selected value-safe Claude/Cursor configuration, and a portable Quick Access manifest. A repository with older-history Gitleaks findings receives a second-scanned current-tree bundle. Files still flagged in that tree are omitted, counted without disclosing their contents, and recovered from GitHub after login.

Task Scheduler metadata proves registration, trigger, state, and recorded result. A successful backup additionally requires a new snapshot, a valid `Recovery\latest.json` pointer, the completed Gitleaks gate, and the documented restore verifier.

`Documents\Agent Backups\Tools\Restore-AgentWorkspace.cmd` restores the latest snapshot on another computer. The restore prefers offline bundles and can use Git remotes after GitHub login. Bitwarden remains the credential authority after an interactive unlock.

`C:\Users\dougl\Documents\Capsule` packages a selected snapshot with the portable harness, software and account manifests, setup map, Bitwarden procedure, restore tools, and SHA-256 integrity records. Brief 21 covers its build and receiving-computer flows.

Exclude:

- tokens, passwords, API keys, access-token files, `.env` files, passcode files, recovery keys, cookies, browser profiles, and vault databases;
- session transcripts, caches, logs, and product authentication state;
- live SQLite write-ahead logs;
- live `.git` internals and worktrees;
- `Data\Restricted` and unreviewed private project material.

## OneDrive exit state

OneDrive's client is uninstalled. Roughly 7.3 GiB of obsolete AppData runtime files were removed on 2026-07-27. The remaining locked runtime residue is scheduled for one-time cleanup at the next sign-in by `C:\Users\dougl\Documents\Agent Backups\Cleanup\Remove-OneDriveResidue.ps1`.

Windows currently maps the known folders to:

- Desktop: `C:\Users\dougl\Desktop`
- Documents: `C:\Users\dougl\Documents`
- Pictures: `C:\Users\dougl\Pictures`

Missing files from the old OneDrive Desktop, non-General-Claude Documents, Pictures, and Attachments folders were copied additively into those normal local folders. Existing destination files were preserved. A read-only Robocopy comparison confirmed no remaining missing-file copy work.

The orphaned `C:\Users\dougl\OneDrive` tree remains the rollback source while:

1. active sessions and linked worktrees leave the retired path;
2. Google Drive Preferences confirms that old OneDrive and live engineering roots are absent;
3. the selected local Desktop/Documents/Downloads folders are synchronized and restore-tested;
4. the remaining collisions are preserved or reviewed;
5. the retired tree receives a final metadata comparison.

The coordination repository is renamed to `C:\Users\dougl\projects\general-ai`. The old `general-claude` path remains rollback while its owning session is active.

## Restore proof

At least quarterly:

1. clone the harness and one project repository into a disposable directory;
2. run their documented verifiers;
3. restore one SQLite snapshot and query it;
4. restore one ordinary project-data file;
5. verify the value-free recovery pointer;
6. record the date and result in the harness changelog.

The dated 2026-07-27 restore proof recorded recovery of one remote project, one local-bundle project, one file-snapshot scaffold, and application data in a disposable directory. Snapshot `20260729-002722` completed its Gitleaks and Capsule integrity gates; it has not yet received a new full disposable-computer restore.

## Snapshot retention

Automatic deletion remains disabled. The proposed policy keeps:

- the most recent 14 daily snapshots;
- 8 additional weekly snapshots;
- 12 additional month-end snapshots;
- every labeled milestone;
- the newest snapshot that passed a full disposable restore.

A future retention tool must produce a dry-run report first and pause when the newest backup, integrity check, Gitleaks scan, or restore verification fails.

## Archived sources

- [`archive/topics/03-STORAGE-AND-SQLITE.md`](archive/topics/03-STORAGE-AND-SQLITE.md) preserves the detailed storage decision examples.
- [`archive/topics/06-GOOGLE-DRIVE-STATUS.md`](archive/topics/06-GOOGLE-DRIVE-STATUS.md) preserves the dated Drive configuration audit and restore drill.

Sources: [Google Drive mirroring and streaming](https://support.google.com/drive/answer/13401938), [Google Drive settings](https://support.google.com/drive/answer/13470231), [CISA ransomware backup guidance](https://www.cisa.gov/stopransomware/ransomware-guide).
