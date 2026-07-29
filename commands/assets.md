---
name: assets
description: "Maintains one append-only ASSETS.md in the vault as the running index of everything produced or configured across sessions — path, type, source session/date, one-line purpose — with an auto-append sweep that detects media created this session (mp4/png/pptx/html decks) and appends entries, location-only entries for agent-set config values (never secret values), and a search-before-build rule (grep ASSETS.md plus reference_local_apps.md before creating any media or app surface). Thin extension of the research-asset-manifest skill's per-folder JSON manifest, not a duplicate — that skill indexes ONE research folder's files in machine-readable JSON for deck/report tooling; this indexes EVERYTHING across ALL sessions/projects in one durable human-readable log mission-control reads. Use when Douglas says 'assets', 'log this asset', 'what have I built', 'check before I build this', 'sweep this session's assets', '/assets'."
---

# /assets [sweep | log <path> | search <term>]

Douglas rebuilds things he already has because nothing durable tracks what got made where. `research-asset-manifest`
already solves this for one research folder's files (papers, figures, decks) as a machine-readable JSON manifest.
`/assets` is a thin extension in a different direction: one running log across ALL sessions and projects, not
scoped to a folder, covering media AND config state, read by mission-control and by Douglas before he builds again.

## Relationship to `research-asset-manifest`

`research-asset-manifest` builds `research_manifest.json` **inside a target research folder**, cataloging that
folder's papers/figures/decks/data for deck and report tooling to consume. `/assets` does not duplicate that —
it maintains `ASSETS.md` **at the vault root**, one line per artifact created across the whole harness, and its
sweep step explicitly **defers to an existing `research_manifest.json`** when a folder has one: if a folder being
swept already has a manifest, `/assets` reads its `assets` array for entries rather than re-scanning that folder
itself, and appends only a pointer line to `ASSETS.md` (`<folder>/research_manifest.json — N assets, see manifest`)
instead of one line per file. `/assets` sweeps folders WITHOUT a manifest directly.

## The file

`ASSETS.md` in the Obsidian vault root (`NASA_GSFC_Vault_1/ASSETS.md`). Append-only — never rewritten, never
reordered, never pruned. Each line:

```
- YYYY-MM-DD | <type> | <path or manifest-pointer> | session:<id-or-name> | <one-line purpose>
```

` | ` is the field delimiter, so the five fields are what mission-control splits on. Keep any literal `|`
out of the `<one-line purpose>` (rephrase, or use `/`); a stray pipe in the purpose splits into a sixth field
and corrupts the record for the reader. On the consumer side, split on the **literal three-character string
`" | "`** — `|` is a regex metacharacter, so a naive `awk -F' | '` reads it as alternation and shreds every
line into single characters (verified: regex split gives the wrong field count). Use `awk -F' [|] '`, a fixed
`split()`, or `sed`, never a bare `|` in a regex field separator.

`<type>` is one of: `media` (mp4/png/pptx/html deck), `app` (a running local surface — dashboard, viewer,
MCP server), `config` (an agent-set value — location only), `manifest-pointer` (a folder already covered by
its own `research_manifest.json`).

## Commands

### `sweep` (default, no argument)

1. Detect files created or modified THIS session matching media extensions (`.mp4`, `.png`, `.jpg`, `.pptx`,
   `.html` decks/dashboards) under the session's working folders. Use git status / file mtimes, not a full
   filesystem crawl.
2. For each candidate folder, check for an existing `research_manifest.json` first (per the relationship
   above). If present, stage one manifest-pointer line and skip per-file entries for that folder. If absent,
   stage one `media`/`app` line per new artifact.
3. For any config value set THIS session via an agent (API keys, endpoints, feature flags written to a
   settings/env file) — stage a `config` line naming the **file and key location only**, never the value.
   `grep`-check the line before writing it: if it would contain anything that looks like a key/token/secret
   value, write `[value redacted — see <file>]` instead of the literal text.
4. **Dedup before appending (idempotent sweep).** For each candidate line, `grep -F` its `<path>` (or
   manifest-pointer) against the current `ASSETS.md` first; skip any path already logged. A sweep run twice
   in one session, or a resumed session re-sweeping the same folders, must not double-log the same artifact —
   re-runs that don't enforce this are the classic near-duplicate failure of append-only inventories.
5. Append the surviving new lines to `ASSETS.md` in one batch; never touch existing lines.

### `log <path> [purpose]`

Append a single explicit entry for one artifact Douglas names, inferring `<type>` from the extension and
`purpose` from context if not given.

### `search <term>`

Grep `ASSETS.md` for `<term>` and report matching lines — this is also the mandatory pre-build check (see
below), invokable directly. **Before surfacing a match as reusable, confirm its `<path>` still exists on
disk** (`test -e`); the log is a derived index and the files are the source of truth, so a logged path that
was later moved or removed is a dead pointer. Report a surviving path as "reuse this", and a missing one as
"logged but now missing — was `<path>`" so a stale entry never blocks a rebuild by pointing at nothing.

## Search-before-build rule

Before creating any new media artifact or app surface (a dashboard, a deck, a viewer, an MCP server), grep
`ASSETS.md` AND `reference_local_apps.md` (if present under `~/.claude/memory/`) for the same purpose or a
close name match first. If a matching entry exists, surface it and ask whether to reuse/extend it rather than
building fresh — this is the actual payoff of the log; a sweep nobody consults before building is dead weight.
This check is cheap (two greps) and runs even when `/assets` itself isn't explicitly invoked, whenever a task
is about to create a new media or app surface.

## Mission-control integration

Mission-control (or any dashboard reading session/project state) reads `ASSETS.md` directly as its asset
inventory — no separate export step. If mission-control's own read path doesn't yet point at this file, that's
a one-line addition to flag, not something `/assets` wires up itself.

## Safety constraints

- **Never write a secret value into `ASSETS.md`.** Config entries are location-only (file + key name). If
  a value can't be confirmed non-secret, redact it rather than guess.
- **Append-only — never rewrite or reorder `ASSETS.md`.** Corrections are new lines, not edits to old ones;
  the log's value is the unbroken history.
- **Never delete an artifact to "clean up" the index.** `/assets` logs; it does not prune, move, or remove
  files it finds.
- **Sweep scope stays session-local.** Don't crawl unrelated projects or the whole filesystem looking for
  media — only folders touched this session, or a path Douglas names explicitly.
- **Defer to an existing `research_manifest.json`** rather than re-cataloging a folder that already has one
  — avoids two conflicting inventories for the same files.

---

*Tracked copy: also save this file to `claude-global-config/commands/assets.md` (per the skills-are-tracked
convention) after a NASA scrub. Run `/ultraskill improve assets` later to add richer mission-control wiring
once a concrete mission-control read path exists to target.*
