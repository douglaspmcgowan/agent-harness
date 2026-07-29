---
name: claude-config-repos
description: Canonical Claude global-config repo is claude-global-config (claude-config is DEPRECATED); ~/.claude tracks it; /claude-sync reconciles drift
metadata:
  node_type: memory
  type: reference
  originSessionId: 96c30446-65ed-45ba-a5f2-76478ce8cc48
---

**Canonical Claude Code global config repo:** `github.com/douglaspmcgowan/claude-global-config` (branch **`master`**). This desktop's `~/.claude` tracks it (re-pointed 2026-05-23).

**DEPRECATED:** `github.com/douglaspmcgowan/claude-config` — early single-commit snapshot, superseded. Its README is now a deprecation banner. **Never push there.**

**Reconcile drift across machines:** run the `/claude-sync` skill (`~/.claude/skills/claude-sync/SKILL.md`). It scans `~/.claude` ↔ repo, merges best-of-both (machine-neutral unified; machine-specific kept per-machine), pushes, and re-points the machine.

**Multi-machine setup:** this desktop + a Yoga laptop both track the repo. Machine-specific bits are **gitignored per-machine**:

- `mcp.json` — drive paths differ (`C:\…\My Drive` on this desktop vs `G:\My Drive` on Yoga).
- `plugins/installed_plugins.json` — per-machine plugin registry.
- `CLAUDE.md` "Obsidian vault" section is **machine-aware**: this desktop → Metropolis vault on Google Drive; Yoga → `C:\Users\dougl\Main\Yoga 7 Local_John 14_12`.

Memory (`projects/*/memory/*.md`) IS committed to the repo — it's the portable layer; session `.jsonl` + UUID dirs are gitignored.
