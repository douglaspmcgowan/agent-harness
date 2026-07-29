# Secret manifest

Project: agent-harness

This generated view contains variable names and operating metadata only. Secret values, vault session keys, recovery keys, and access tokens are forbidden.

| Variable | Purpose | Provider | Trust boundary | Owner | Rotation | Consumers | Status |
|---|---|---|---|---|---|---|---|
| `BWS_ACCESS_TOKEN` | Authenticate one computer's read-only Bitwarden Secrets Manager broker session. | Bitwarden Secrets Manager | local agent broker | Douglas | on compromise, device retirement, ownership change, or provider policy | .agents/tools/Invoke-WithBitwardenSecret.ps1 | bootstrap-required |
| `PROJECT_DATA_ROOT` | Locate this computer's external per-project data root. | Windows user environment | local configuration | Douglas | when the local data root moves | .agents/tools/Sync-SqliteProjectData.ps1 | non-secret-config |
| `PROJECT_DATA_SYNC_ROOT` | Locate the Google Drive root used by reviewed external-data adapters. | Windows user environment | local configuration | Douglas | when the Google Drive sync root moves | .agents/tools/Sync-SqliteProjectData.ps1 | non-secret-config |

Canonical source: `secret-manifest.json`
Refresh: `C:\Users\dougl\.agents\tools\Update-SecretManifest.cmd -Repository <repo>`
