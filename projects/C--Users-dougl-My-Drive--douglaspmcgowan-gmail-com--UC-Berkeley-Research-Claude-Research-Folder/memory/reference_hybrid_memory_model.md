---
name: hybrid-memory-model
description: "How Doug's two memory layers fit together — local auto-memory (machine-specific) + vault project-logs (cross-machine via /save-context). Read when deciding where to persist something or when resuming on a different machine."
metadata:
  node_type: memory
  type: reference
  originSessionId: 96c30446-65ed-45ba-a5f2-76478ce8cc48
---

# Hybrid memory model (chosen 2026-05-24)

Doug works across **two machines** (this desktop, Drive-synced `C:\...My Drive...`; and the Yoga laptop, `G:\` / local). He wanted to know whether to migrate all auto-memory into the Obsidian vault for a single cross-machine store. Decision: **hybrid, not full migration.**

**Two layers, deliberately separate:**

1. **Local auto-memory** — `~/.claude/projects/<absolute-cwd-key>/memory/` + `MEMORY.md`. Harness-wired and **auto-recalled** every session, but **keyed by absolute cwd path**, so it does NOT transfer across machines (the Yoga laptop has a different path key). Keep this as the fast, automatic, per-machine layer.
2. **Vault project-logs** — `<vault>/Claude/Memory/Projects/<repo>.md` (from `_TEMPLATE.md`), written by **[[reference-claude-config-repos|/save-context]]** and read by `/resume-context`. The vault syncs to the Yoga laptop via **Obsidian Sync** (NOT Google Drive), so this IS the cross-machine memory layer.

**Why not migrate auto-memory into the vault:** you'd lose automatic recall (the harness only auto-loads the local path), and you'd duplicate state. The vault layer is opt-in (run `/save-context`) but portable; the local layer is automatic but pinned to the machine. Hybrid keeps both strengths.

**How to apply:**

- Per-machine behavioral/user/feedback memories → local auto-memory (here).
- Cross-machine project decisions/state that must survive a machine switch → `/save-context` → vault project-log + repo `STATUS.md`.
- Resuming on either machine → `/resume-context` reads repo `CURRENT-TASK.md` → `STATUS.md` → vault log (see [[reference-claude-config-repos]] / save+resume skills). Repo identified by cwd or name via `repo-map.md`.
