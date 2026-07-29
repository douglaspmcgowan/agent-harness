# Project data sync and recovery

Capsule carries the shared global harness and its committed approved Obsidian snapshot. Each project uses its GitHub repository and `data-manifest.yaml` to reconstruct the rest of its working state.

## Transport map

| Material | Authority | How another computer receives it |
|---|---|---|
| Source, project rules, migrations, handoffs, and small safe fixtures | Project GitHub repository | Clone once; fetch and integrate later commits |
| Shared global harness | Harness GitHub repository and global Capsule | Install from Capsule or project the checked-out harness |
| Local working data | `%USERPROFILE%\Data\Projects\<project>` | Restore through the project's reviewed adapter |
| Immutable snapshots, exports, media, and large artifacts | Google Drive `My Drive\Project Data\<project>` or another manifest-declared store | Adapter fetch plus checksum/schema verification |
| Live shared application records | Project-declared network service | API connection plus migration and export policy |
| Runtime secrets | Bitwarden Secrets Manager | Exact-command broker with a read-only machine account |
| Approved Obsidian settings | Committed harness snapshot with per-file digests | Deliberate capture, Git review, Capsule projection, and verified receiving restore |

## Standard environment

Bootstrap configures these user values:

```text
PROJECT_DATA_ROOT=%USERPROFILE%\Data\Projects
PROJECT_DATA_SYNC_ROOT=<Google Drive My Drive>\Project Data
```

The local root holds writable working data. The sync root holds completed, portable artifacts. A live SQLite database stays in the local root; a consistent SQLite snapshot may be published to Drive by a reviewed adapter.

The SQLite adapter requires both declared roots. It rejects a database outside `PROJECT_DATA_ROOT`, a snapshot outside the project's directory under `PROJECT_DATA_SYNC_ROOT`, and any source, destination, root, or existing ancestor implemented through a Windows junction, symbolic link, or other reparse point.

## Data-manifest workflow

After cloning a project:

1. read `data-manifest.yaml`;
2. identify every external asset and its authority;
3. run the executable-discovery audit and install a missing adapter dependency in an isolated per-user tool environment;
4. run only the declared adapter;
5. verify the expected version, checksum, schema, or integrity proof;
6. run the project verifier;
7. record any unavailable asset as a blocker.

Files outside GitHub and every declared adapter have no reliable cross-computer route. Add a reviewed manifest entry before relying on them.

## Routine update cycle

### Working computer

1. Commit and push durable project work.
2. Push shared-harness changes to the harness repository.
3. Run each changed project's external-data adapter.
4. Let Google Drive finish syncing completed artifacts.
5. Capture and commit approved Obsidian changes before refreshing and verifying Capsule.

### Other computer

1. Fetch and integrate eligible GitHub changes.
2. Run the project's declared external-data adapter.
3. Verify restored artifacts and project behavior.
4. Pull live state through the project's network service.
5. Use the exact-command broker when an approved process needs a secret.

## Find Capsule in Google Drive

The canonical cross-computer location is `My Drive\Capsule`. The source computer currently exposes it as `C:\Users\dougl\My Drive\Capsule`.

Google Drive for desktop may expose My Drive under `%USERPROFILE%\My Drive` or through a mounted-drive shortcut. The browser link is:

<https://drive.google.com/drive/folders/197x4O5pCj5cuXETXuv72zeCdvkVSDJSj>

Make the folder available offline, copy it to local staging, and run the verifier from the staging copy.

## Retention

Capsule integrity records describe the current assembled package. They are independent from project-data and local recovery retention.

Every project chooses retention from its recovery objective and update frequency. Until a project has an approved pruning tool:

- keep completed artifacts with their checksums and dates;
- keep the newest artifact that passed a full restore;
- protect manually labeled milestones;
- pause pruning after a failed backup, integrity check, or restore;
- require a dry-run inventory before deletion.

The optional nightly `Backup-AgentWorkspace` and `Restore-AgentWorkspace` workflow remains a separate local recovery layer. It has no role in Capsule packaging or project synchronization.

## Phone-safe links

Use a GitHub web link for repository state and a Google Drive share link for an external artifact. Use the deployed authenticated application URL for live state.
