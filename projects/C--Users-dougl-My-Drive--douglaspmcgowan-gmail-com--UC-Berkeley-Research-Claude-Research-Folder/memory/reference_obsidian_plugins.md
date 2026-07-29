---
name: obsidian-plugins
description: "Where the Metropolis vault's plugin capabilities are documented, and what Claude should reach for (dataview, excalidraw, canvas, kanban, charts, MCP)"
metadata:
  node_type: memory
  type: reference
  originSessionId: 96c30446-65ed-45ba-a5f2-76478ce8cc48
---

The Metropolis vault has ~31 enabled plugins. The canonical **Claude-readable index** is `Claude/Plugin Map.md` in the vault (terse table: id / name / category / what / Claude-use). Human-facing companions: `Obsidian Usage/Plugin Showcase.md` (narrative, shareable) and `Obsidian Usage/Plugin Dashboard.md` (Dataview cards). Per-plugin notes live in `Obsidian Usage/Plugins/`.

Capabilities Claude should use:

- **Diagrams** → Mermaid (```mermaid), Canvas (.canvas JSON), `advanced-canvas`(presentations),`obsidian-excalidraw-plugin` (.excalidraw.md scenes).
- **Live dashboards / cards** → `dataview` (stable DQL) or `datacore` (editable, beta). Card layout = note frontmatter `cssclasses: cards` + a Dataview TABLE.
- **Charts** → `obsidian-charts` (```chart, Chart.js).
- **Boards** → `obsidian-kanban` (markdown, frontmatter `kanban-plugin: board`).
- **Vault read/write from Claude Code** → `mcp-tools` + `obsidian-local-rest-api`.

Theme: **Minimal** (kepano). CSS snippets: `canvas-clean`, `wide-editor` (readable line length → ~80%). See [[maintain-plugin-map]].
