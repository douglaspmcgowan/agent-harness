# Agent start

`README.md` is the canonical human and agent entry point. This compatibility file preserves older links to `AGENT-START.md`.

## Read in order

1. `README.md`
2. `START-HERE.md`
3. `SYSTEM-MAP.md`
4. `DATA-SYNC-AND-RETENTION.md`
5. `SECRETS-BITWARDEN.md`
6. `NEXT-STEPS.md`

## Operating boundary

- Capsule carries the shared global harness and the approved Obsidian snapshot committed with that harness revision.
- GitHub carries every project's committed source, rules, handoffs, migrations, and small safe data.
- Project-specific external data follows the authority and adapter declared in `data-manifest.yaml`.
- Google Drive carries Capsule and reviewed immutable project-data artifacts.
- Bitwarden Secrets Manager supplies runtime secrets through a per-computer machine account and the exact-command broker.
- Phone-readable repository material uses GitHub links; external artifacts use Google Drive links.

Never access vault notes or prohibited locations while exporting or restoring Obsidian configuration. The prohibited locations include `AI Reference\`, `26_Sensitive\`, `40_Reference\AI Reference.md`, `31_Business\Other People Reference.md`, and `G:\My Drive\Actual Documents\Identity`.

## Receiving workflow

1. Copy `My Drive\Capsule` to a local staging folder outside every sync root.
2. Clone the known harness repository and run its verifier before any packaged script:

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

3. Stop for a failed verifier, ambiguous active Obsidian vault, or account-owner authentication.
4. Store the Bitwarden Secrets Manager machine token with `Set-BwsMachineToken.ps1`.
5. Discover and clone GitHub repositories carrying the `agent-project` topic.
6. Run every repository verifier and required data-manifest adapter.

After installation, continue from the receiving repository's `AGENTS.md`, `TASK.md`, `STATUS.md`, and `MAP.md`.
