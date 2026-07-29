# Start here on another computer

Capsule installs the shared global harness and its Git-authenticated approved Obsidian snapshot. GitHub reconstructs projects. Each project's `data-manifest.yaml` directs any external-data restore.

## Short receiving checklist

1. Sign into Google Drive for desktop with the account listed in `manifests\accounts.json`.
2. Open **My Drive → Capsule** or use the Drive folder link:
   <https://drive.google.com/drive/folders/197x4O5pCj5cuXETXuv72zeCdvkVSDJSj>
3. Make the folder available offline.
4. Copy it to a local staging folder outside every sync root, such as `C:\Users\<you>\Capsule-Staging`.
5. Open PowerShell in that staging folder.
6. Clone the known harness repository, then run its verifier against the staged Capsule:

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

7. Complete the required product sign-ins.
8. Follow `SECRETS-BITWARDEN.md` to store this computer's Bitwarden Secrets Manager machine token.
9. Use the installed `Sync-AgentRepositories.ps1` tool to discover and clone repositories carrying the `agent-project` topic.
10. Run every cloned repository's verifier and required `data-manifest.yaml` adapters.

## What arrives

- `payload\harness\.agents`: the portable shared harness;
- `payload\obsidian\config`: the approved Obsidian snapshot authenticated by the recorded harness Git revision;
- `manifests`: software, account identifiers, exact Git provenance, Capsule pointer, and SHA-256 integrity records;
- `tools`: bootstrap, refresh, Obsidian restore, project-data environment, and verification scripts.

Project repositories and runtime project data travel through their declared authorities.

## Standard project-data paths

Bootstrap configures:

```text
PROJECT_DATA_ROOT=%USERPROFILE%\Data\Projects
PROJECT_DATA_SYNC_ROOT=<Google Drive My Drive>\Project Data
```

The first path is the local working-data root. The second holds reviewed portable snapshots, exports, media, or other immutable artifacts. A live database stays with its declared network service or local adapter.

## Safe links from a phone

- Use a GitHub web link for repository files, task state, and documentation.
- Use a Google Drive share link for Capsule and external artifacts.
- Use the deployed authenticated application URL for live app state.

Read `README.md` for operating details, `SYSTEM-MAP.md` for the connections, and `NEXT-STEPS.md` for the remaining human actions.
