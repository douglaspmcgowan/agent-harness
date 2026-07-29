# Cross-Agent Harness

This repository is the public, portable source for the shared Claude, Codex, and Cursor harness.

Start here:

- [Human guide](.agents/human-readable/README.md) — architecture, data flow, task state, hooks, skills, Bitwarden, Docket, backups, and receiving-computer setup.
- [HTML guide](.agents/human-readable/README.html) — the same guide with rendered Mermaid maps.
- [Capsule](.agents/capsule/README.md) — install, sync, verify, backup, and restore from another Windows computer.
- [Global manager](.agents/tools/Manage-Harness.ps1) — idempotent global installation, project setup, verification, hook activation, and integrity stamping.

Verify the repository from PowerShell:

```powershell
.\.agents\tools\Manage-Harness.ps1 -Action VerifyGlobal -HarnessRoot .\.agents
.\.agents\task-hooks\tests\Run-All.ps1
.\.agents\capsule\Capsule-Portability.Tests.ps1
```

The manager preserves the live Codex `AGENTS.md` and writes a section-by-section edit proposal under `.agents\adapters\codex`.
