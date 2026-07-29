# Obsidian access — operational guide for Claude

Read when Doug asks to read/search/write his Obsidian vault ("in Obsidian", "my notes", "the vault").

**Vault path & sync — CHECK, don't assume.** Before reading/writing, open `%APPDATA%\obsidian\obsidian.json` and use the vault with `"open":true` on the current machine. The same content lives in several synced copies (plain markdown):

- **Local "Yoga" vault** `C:\Users\dougl\Main\Yoga 7 Local John 1412` (+ twin `...Yoga 7 Local_John 14_12`) → **Obsidian Sync** remote **"John 14:12"** (host `sync-33.obsidian.md`, E2E-encrypted). Sync config is in app-level leveldb (`%APPDATA%\obsidian\Local Storage` / `IndexedDB`), **NOT** a `sync.json` in the vault — so no `sync.json` ≠ sync off. (The encryption key sits in that leveldb — never print it.)
- **Google-Drive "Metropolis" vault** `G:\My Drive\Obsidian\Metropolis Pt. 1--The Maverick And The Test` → **Google Drive**.
- The **ThinkPad bridges** them (runs Obsidian on the Drive-Metropolis folder _and_ on Obsidian Sync). The bridge is **intermittent** (only when the ThinkPad is on) and is a **dual-sync conflict risk**. **Write to the open vault only; let sync propagate; never edit two copies.** To enumerate sync vaults, extract `appId`/`vaultId`/`Name`/`host` strings from the leveldb.

**Plugins & capabilities** — `Claude/Plugin Map.md` in the vault is the Claude-readable index of all ~31 enabled plugins and what to reach for (diagrams: Mermaid/Canvas/Excalidraw/advanced-canvas; dashboards/cards: Dataview/Datacore; charts: obsidian-charts; boards: Kanban). Human-facing: `Obsidian Usage/Plugin Showcase.md` + `Obsidian Usage/Plugin Dashboard.md`. **Update the Plugin Map when plugins change.** Active theme: Minimal.

## Pick the access path by task

| Task                                              | Use                                                                                                  |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Keyword / filename / exact string                 | **filesystem** Grep/Glob (always works; default here)                                                |
| Read / edit / create a specific note              | **Obsidian MCP if connected**, else **filesystem** Read/Write/Edit                                   |
| Meaning / "what do I know about X" / fuzzy recall | **Smart Connections → Lookup** (Doug runs it; Claude can't query it). Grep is keyword-only — say so. |
| Bulk reorg / rename / re-link                     | **filesystem** (batch it — Drive sync), then tell Doug to let Smart Connections re-embed             |
| Chat / synthesize across many notes               | Smart Connections Smart Chat or Copilot (Doug), or Claude reads candidates + reasons                 |

## State to verify (changes)

- **Obsidian MCP** = HTTP server `localhost:3001/mcp`, configured in Claude Code. Only up when the vault's MCP plugin (`mcp-tools` / `semantic-vault-mcp`) is **enabled** and Obsidian is running. Check `claude mcp list`; if obsidian shows ✗, use filesystem.
- **Smart Connections / Copilot** are vault plugins (Doug-facing). If `community-plugins.json` is `[]` / Restricted Mode is on, they're OFF — flag it.

## Guardrails

- **`26_Sensitive/` is completely off-limits.** Never read, edit, glob, grep, or link any file inside it. No exceptions, no matter the task. Exclude from all bulk operations, linking passes, and any cloud/git mirror.
- **The `AI Reference/` folder (vault root) and `40_Reference/AI Reference.md` are completely off-limits.** They hold credentials/secrets. Exclude from all searches, reads, globs, and any cloud/git mirror. Enforced by `protect-ai-reference.js`.
- Don't touch `.smart-env/` (embeddings cache, ~114 MB) or `.obsidian/` via filesystem **while Obsidian is running**.
- `block-obsidian-delete` hook blocks MCP vault deletes; deletions stay manual.
- Heavy file churn ⇒ large Drive sync; batch it.
