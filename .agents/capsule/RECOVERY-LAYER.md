# Optional local workspace recovery

The global Capsule workflow uses GitHub for projects, per-project manifests for external data, and Capsule for the shared harness plus approved Obsidian configuration.

`Backup-AgentWorkspace.ps1` and `Restore-AgentWorkspace.ps1` remain available as a separate optional local recovery workflow. They can capture reviewed uncommitted work, offline Git bundles, and selected project data for a deliberate restore. Their snapshots stay outside `My Drive\Capsule` and have no role in routine project synchronization.

Use this layer when a project has unpublished local work that GitHub and its data adapter cannot yet reconstruct. Verify every snapshot and restore in a disposable target before relying on it.

The legacy restore command remains:

```powershell
& "$env:USERPROFILE\.agents\tools\Restore-AgentWorkspace.ps1" `
  -BackupRoot "$env:USERPROFILE\Documents\Agent Backups\Workspace"
```

For normal receiving-computer setup:

1. install the shared harness from Capsule;
2. clone projects from GitHub;
3. run each project's reviewed `data-manifest.yaml` adapter;
4. store the Bitwarden Secrets Manager machine token;
5. verify the harness and every project.

Local recovery retention is chosen separately from Capsule integrity. Keep the newest snapshot that passed a full disposable restore, protect labeled milestones, and require a dry-run inventory before pruning.
