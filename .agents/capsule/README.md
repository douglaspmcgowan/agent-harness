# Capsule

This is the human and agent entry point for rebuilding Douglas's shared cross-agent setup on another Windows computer.

Point the receiving agent at this folder and say:

> Read `README.md`, copy this Capsule to local staging, verify it, install the shared harness, restore the approved Obsidian configuration, and reconstruct projects from GitHub and their data manifests. Stop for account-owner authentication or a failed verifier.

## What Capsule carries

Capsule carries:

- the shared global `.agents` harness;
- bootstrap, refresh, and verification tools;
- value-safe account and software instructions;
- the approved portable configuration from the single active Obsidian vault;
- integrity metadata and these entry documents.

Capsule excludes project checkouts, project handoffs, repository bundles, application databases, and workspace snapshots. GitHub reconstructs each project. Reviewed adapters declared in each repository's `data-manifest.yaml` reconstruct external project data.

## Authorities

| Concern | Authority |
|---|---|
| Shared global harness | The harness GitHub repository and the installed `%USERPROFILE%\.agents` folder |
| Project source, rules, handoffs, migrations, and small safe data | Each project's GitHub repository |
| Large or excluded project data | The authority and adapter declared in that project's `data-manifest.yaml` |
| Portable immutable artifacts | Google Drive under `My Drive\Project Data\<project>` |
| Live shared application state | The network service declared by that project |
| Runtime secrets | Bitwarden Secrets Manager through the exact-command broker |
| Portable Obsidian settings | Capsule's approved `payload\obsidian\config` payload |

## Command surface

Run Capsule lifecycle operations through `Harness.ps1`:

```powershell
& ".\Harness.ps1" `
  -Action verify `
  -HarnessRepository "$env:USERPROFILE\projects\agent-harness"
& ".\Harness.ps1" `
  -Action install `
  -HarnessRepository "$env:USERPROFILE\projects\agent-harness"
```

| Action | Result |
|---|---|
| `verify` | Validates the manifest, every integrity record, the global-harness boundary, the approved Obsidian-config allowlist, and the harness payload against an external trusted Git checkout |
| `install` | Verifies first, installs the global harness, restores approved Obsidian settings with a backup, and configures the project-data environment |
| `sync` | Builds and verifies a fresh global-only Capsule from one exact harness revision and its committed approved Obsidian snapshot |

There are no `backup` or `restore` workspace actions in this command surface.

## Receiving computer

1. Sign into the same Google account in Google Drive for desktop.
2. Open **My Drive → Capsule**. The source computer currently uses `C:\Users\dougl\My Drive\Capsule`.
3. Make the complete folder available offline.
4. Copy it to a local staging folder outside every sync root, such as `C:\Users\<you>\Capsule-Staging`.
5. Open PowerShell in the staging folder.
6. Run:

```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\projects" -Force | Out-Null
gh repo clone ai-consulting-1/doug-harness "$env:USERPROFILE\projects\agent-harness"
& "$env:USERPROFILE\projects\agent-harness\.agents\capsule\Verify-Capsule.ps1" `
  -CapsuleRoot (Get-Location).Path `
  -TrustedHarnessRepository "$env:USERPROFILE\projects\agent-harness"
& ".\Harness.ps1" `
  -Action install `
  -HarnessRepository "$env:USERPROFILE\projects\agent-harness"
```

7. Complete the account-owner sign-ins for GitHub, Google Drive, Bitwarden, Claude, Codex, Cursor, and Obsidian when prompted.
8. Install or verify the Bitwarden Secrets Manager CLI and follow `SECRETS-BITWARDEN.md`.
9. Discover and clone the GitHub repositories carrying the `agent-project` topic.
10. Run each repository's verifier and each required adapter from its `data-manifest.yaml`.

Bootstrap sets these standard paths when their existing values are missing, invalid, or tied to a retired OneDrive path:

- `PROJECT_DATA_ROOT=%USERPROFILE%\Data\Projects`
- `PROJECT_DATA_SYNC_ROOT=<Google Drive My Drive>\Project Data`

Valid existing directories are preserved.

## Source computer refresh

When approved Obsidian settings change, deliberately capture them into the harness worktree:

```powershell
& "$env:USERPROFILE\projects\agent-harness\.agents\capsule\Capture-ApprovedObsidianConfig.ps1" `
  -HarnessRepository "$env:USERPROFILE\projects\agent-harness"
```

Review the generated `approved-obsidian-config` diff, run verification, and commit and push it with the harness change. Then refresh production Capsule:

```powershell
& "$env:USERPROFILE\projects\agent-harness\.agents\capsule\Harness.ps1" `
  -Action sync `
  -CapsuleRoot "$env:USERPROFILE\My Drive\Capsule" `
  -HarnessRepository "$env:USERPROFILE\projects\agent-harness"
```

Wait for Google Drive to report **Up to date**, then run the verifier from the trusted harness checkout against the Drive copy.

## Obsidian boundary

The capture command discovers the single active vault through `%APPDATA%\obsidian\obsidian.json` and writes only approved settings, snippets, theme files, and normalized community-plugin IDs into a tracked snapshot with file digests. Refresh never reads live vault bytes. It reconstructs that snapshot from the exact committed Git revision. Restore validates the complete payload before changing the receiving vault and backs up overwritten configuration under `.obsidian-backups`.

Vault notes, workspace state, bookmarks, sync state, plugin data, caches, credentials, and runtime files stay outside the package. Agents must never access:

- `AI Reference\`;
- `26_Sensitive\`;
- `40_Reference\AI Reference.md`;
- `31_Business\Other People Reference.md`;
- `G:\My Drive\Actual Documents\Identity`.

## Secrets

The selected authority is Bitwarden Secrets Manager in the `Agents` organization. One Secrets Manager project named `Agent Runtime` can hold prefixed secrets for many application repositories. Each computer receives its own read-only machine account.

The one-time setup on each computer is:

```powershell
& "$env:USERPROFILE\.agents\tools\Set-BwsMachineToken.ps1"
```

Paste the machine-account access token only into that secure prompt. The script stores it in Windows Credential Manager. Later approved commands use a command ID:

```powershell
& "$env:USERPROFILE\.agents\tools\Invoke-WithBitwardenSecret.ps1" `
  -CommandId "docket-sync" `
  -BwsPath "$env:USERPROFILE\Tools\bws\bws.exe"
```

The allowlist binds the command ID, executable, full arguments, working directory, Bitwarden project ID, secret ID, and destination environment variable. The broker injects secrets only into the approved child process and redacts captured output. Routine invocations do not require another interactive Bitwarden login.

## Phone and browser links

Windows paths work only on a computer with that checkout. Share web links:

- repository files and status: a GitHub `blob` or commit-permalink URL;
- Capsule and external artifacts: a Google Drive share link;
- live application state: the project's deployed authenticated URL.

Keep credential values out of GitHub and Drive links.

## Safety and stopping conditions

Refresh, bootstrap, and Obsidian restore use exclusive locks and reject unsafe reparse-point paths. Refresh packages the committed `.agents` tree reconstructed from Git. Verification requires the recorded revision to remain reachable from the known checkout's origin refs, then compares its release identifier, Git tree, file inventory, file hashes, projected entrypoints, and projected instructions. It also rejects undeclared top-level content, workspace/project payloads, malformed Obsidian plugin metadata, and integrity mismatches.

Stop when:

- Capsule verification fails;
- the active Obsidian vault cannot be resolved uniquely;
- a required account needs Douglas's authentication;
- a project lacks a reviewed external-data route;
- a dirty or diverged Git checkout needs reconciliation.

Read `SYSTEM-MAP.md` for the full connection map, `START-HERE.md` for the short receiving checklist, and `NEXT-STEPS.md` for the remaining human-gated actions.
