# Google Drive status and backup coverage

Audit date: 2026-07-27

## Current state

OneDrive is inactive and uninstalled. Its former data tree remains locally at `C:\Users\dougl\OneDrive` while migration and restore verification finish.

Google Drive for desktop 128.0.0.0 is installed and running. On 2026-07-27, a read-only query of `root_preference_sqlite.db` confirmed these nine configured "Folders from your computer" roots:

- `C:\Users\dougl\.agents`
- `C:\Users\dougl\.claude`
- `C:\Users\dougl\.codex`
- `C:\Users\dougl\Data`
- `C:\Users\dougl\Downloads`
- `C:\Users\dougl\OneDrive\Desktop`
- `C:\Users\dougl\OneDrive\Documents`
- `C:\Users\dougl\projects`
- `C:\Users\dougl\Worktrees`

`Downloads` is intentional personal-file coverage and stays selected. The remaining roots include product sessions and authentication state, local/private data, live Git internals, disposable worktrees, ignored credentials, and the retired OneDrive tree.

## Exact cleanup in Google Drive Preferences

1. Open Google Drive for desktop.
2. Open **Settings → Preferences**.
3. Confirm the signed-in Google account.
4. Under **Folders from your computer**, keep `C:\Users\dougl\Downloads`.
5. Remove `.agents`, `.claude`, `.codex`, `Data`, `projects`, `Worktrees`, old OneDrive Desktop, and old OneDrive Documents. Choose **Done**, then **Stop syncing** for each removed folder.
6. Add:

```text
C:\Users\dougl\Desktop
C:\Users\dougl\Documents
```

`C:\Users\dougl\Documents\Agent Backups` is already covered by the Documents selection. Do not add the nested folder separately.

7. Save the preferences.
8. Wait for **Up to date**.
9. Verify Desktop, Documents, and Downloads under **Computers** on Drive web.
10. Run the restore drill below.

Google's supported removal flow is to select a computer folder in Preferences, remove its sync selection, choose **Done → Stop syncing**, and save. [Google Drive settings](https://support.google.com/drive/answer/13470231), [folder-removal procedure](https://support.google.com/drive/thread/238352322/how-do-i-remove-a-synced-folder-from-the-windows-google-drive-app).

## Backup model

| Material | Authority | Google Drive role |
|---|---|---|
| Desktop, Documents, Downloads | Local Windows folders | Continuously mirrored while Drive is running and sync is active |
| Committed source and harness history | Private GitHub repositories | None required |
| Human harness documentation | Private harness repository under `.agents\human-readable` | Optional sanitized export |
| Docket source | `douglaspmcgowan/docket` | None required |
| Docket SQLite data | `C:\Users\dougl\.docket-local` | Consistent SQLite backup exported into `Agent Backups` |
| Valuable project inputs and outputs | Project data manifest | Approved snapshot into `Agent Backups` |
| Product sessions, caches, auth state | Product-owned local folders | Excluded |
| Restricted/private data | Project-specific restricted storage | Excluded unless separately approved |
| Worktrees and live `.git` directories | Reproducible Git state | Excluded |

## Backup frequency

Google Drive watches the selected Desktop, Documents, and Downloads folders and uploads changes automatically while Drive for desktop is running, signed in, online, and unpaused. This is continuous synchronization rather than a once-per-day job.

`Agent Backups` currently has no scheduled task. Its files are created or refreshed at relevant events:

- `harness-backup.json` after a verified harness push;
- handoffs at session rollover or migration boundaries;
- future SQLite snapshots before risky migrations and on the cadence defined by each application.

Recommended future automation is a nightly consistent snapshot for mutable SQLite/application data plus the existing event-driven refresh after harness changes. The current machine does not yet have that nightly task.

## Restore drill

1. Place a disposable non-sensitive file in `C:\Users\dougl\Documents\Agent Backups`.
2. Wait for Google Drive to report **Up to date**.
3. Confirm the file on Drive web.
4. Delete it locally and confirm it reaches Drive trash.
5. Restore it from Drive web.
6. Confirm it returns locally.
7. Remove the test file and record the result in the harness changelog.

Synchronized deletion can propagate, so Google Drive is a recoverability layer alongside Git history and consistent snapshots. [Google Drive mirroring guidance](https://support.google.com/drive/answer/13401938).
