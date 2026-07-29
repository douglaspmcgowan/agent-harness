# DVC project-data adapter

Use this adapter for a large file or directory whose exact bytes must follow a Git revision.

## Authority and paths

- Git stores the generated `.dvc` metadata.
- Google Drive Desktop carries the content-addressed DVC remote under `%PROJECT_DATA_SYNC_ROOT%\<project>\dvc\<asset-id>`.
- The usable project copy lives under `%PROJECT_DATA_ROOT%\<project>\<local_destination>`.
- `.dvc\config.local` stores the current computer's Drive path and remains outside Git.

This mounted-folder design reuses the user's authenticated Google Drive Desktop session. It does not open a separate DVC Google OAuth flow.

## Receiving-computer prerequisite

The receiving agent runs the executable-discovery audit first. When `dvc.exe` is absent, the agent installs DVC in an isolated per-user `pipx` environment, adds `%USERPROFILE%\.local\bin` to the user PATH, opens a fresh PowerShell process, and verifies `dvc --version`. Douglas does not need to invoke DVC himself. The adapter also resolves the standard `pipx` location directly while a newly updated PATH propagates.

## Project declaration

Copy the entry from `dvc-data-manifest.asset.yaml` into the project's `data-manifest.yaml`. Replace every bracketed value. The asset ID stays stable after the first publication.

## Agent workflow

1. Run `Inspect` and record `metadata_sha256`.
2. For the first publication, run `Publish` without `ExpectedMetadataSha256`.
3. For every later publication, pass the exact checksum returned by `Inspect`. The adapter rejects a missing or stale checksum, uncommitted metadata, a checkout whose tracked Git remote has advanced, and an unavailable existing DVC remote. Wait for Drive to sync an existing remote. A first publisher may create its current computer's remote replica; a publisher with existing metadata never recreates a missing remote.
4. Commit the generated `.dvc` file, `.dvc` project configuration, and `.gitignore` changes with the related code revision.
5. On another computer, clone or pull the Git revision, allow Google Drive Desktop to finish syncing the DVC remote, run `Retrieve`, then run `Verify`.
6. If the destination already contains different bytes, resolve or preserve that local copy first. Retrieval stops without overwriting it.

The adapter accepts files and directories, validates containment and nested reparse points, publishes into a content-addressed remote, reports SHA-256 evidence, and uses a temporary sibling before placing a newly retrieved destination. DVC content objects form immutable, additive generations. A failed publication restores prior local staging and DVC configuration while leaving the remote directory and every remote object in place. This can retain an unreferenced partial upload; that is safer than deleting bytes another Google Drive replica may have synchronized.

Google Drive Desktop does not provide a distributed filesystem lock. Each computer can create a lock in its own local replica before Drive reconciliation. The adapter's temporary `%TEMP%` claim only reduces simultaneous first-publication collisions among processes on the same Windows filesystem. It establishes no cross-computer ownership. The normal guarded Git push is the cross-computer compare-and-swap for the committed `.dvc` pointer; a racing second Git push is rejected, while both publishers' immutable content objects remain recoverable.

## Retention

DVC objects referenced by retained Git branches or tags remain available. Do not run `dvc gc` automatically.

For separate SQLite snapshot-style recovery exports, the default is:

- 3 daily recovery points;
- 4 weekly recovery points;
- 3 monthly recovery points.

A project may override these counts in its own recovery policy with nonnegative integers. A zero value disables that time bucket; even `0/0/0` preserves the newest verified snapshot.

`Sync-SqliteProjectData.ps1 -Action Export` creates the new snapshot and reports `PruneInventory` without deleting prior recovery points. Run `-Action Prune` to inspect the current inventory again. Add `-ApplyRetentionPrune` only after reviewing that inventory. The apply phase verifies the newest snapshot checksum and SQLite integrity, restores it into a disposable database, and then deletes the inventoried expired points.
