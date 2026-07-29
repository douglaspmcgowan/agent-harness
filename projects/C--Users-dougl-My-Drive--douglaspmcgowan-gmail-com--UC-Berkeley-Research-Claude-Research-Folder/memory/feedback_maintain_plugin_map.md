---
name: maintain-plugin-map
description: "When enabling/removing an Obsidian plugin, update the Plugin Map + showcase + dashboard + kanban so the record stays usable"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 96c30446-65ed-45ba-a5f2-76478ce8cc48
---

When you install, enable, or remove an Obsidian plugin in the Metropolis vault, update the documentation set — don't leave it stale.

**Why:** Doug explicitly asked that the plugin map stay connected to memory and CLAUDE.md so it's actually usable (not a one-off), and that he keep a maintained, shareable record of his plugins + how he uses each with Claude.

**How to apply:** Update `Claude/Plugin Map.md` (the terse Claude-readable index) FIRST, then `Obsidian Usage/Plugin Showcase.md` (human narrative), add/remove the per-plugin note in `Obsidian Usage/Plugins/`, and move the card in `Obsidian Usage/Plugins Kanban.md`. Keep the Plugin Map row terse. See [[obsidian-plugins]].
