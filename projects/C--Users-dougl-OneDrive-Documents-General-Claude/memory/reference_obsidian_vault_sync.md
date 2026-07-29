---
name: reference-obsidian-vault-sync
description: "Doug's actual Obsidian vault locations and sync setup — which is active, which is synced how (corrects CLAUDE-obsidian.md assumptions)"
metadata:
  node_type: memory
  type: reference
  originSessionId: 74f9d6d8-2f05-46ee-8261-c13a8afbcb83
---

On the machine used June 2026 (the **Yoga laptop**), the **active, currently-open Obsidian vault** is a LOCAL folder, NOT the Google Drive Metropolis vault. Verified via `%APPDATA%\obsidian\obsidian.json` (`"open":true`) and a sync screenshot.

**Active vault (write notes HERE):** `C:\Users\dougl\Main\Yoga 7 Local John 1412`

**Obsidian Sync:** Enabled and "Fully synced." Config is stored in app-level leveldb (`%APPDATA%\obsidian\Local Storage` / `IndexedDB`), NOT in any `sync.json` in the vault — so absence of `sync.json` does NOT mean sync is off.

- Remote (cloud) vault name: **"John 14:12"** (a Bible-verse theme; matches the "Yoga 7 Local_John 14_12" folder naming), vaultId `0f8a54d44cf1c56981f012f5fc217894`, host `sync-33.obsidian.md`, end-to-end encrypted (key is in leveldb — never print it).
- TWO local folders both connect to the same remote "John 14:12": `Yoga 7 Local John 1412` (open, appId 080248eb2434b8c0) and `Yoga 7 Local_John 14_12` (appId 4a968a30470998d8). They mirror each other through the cloud. A third folder `Yoga 7 Local_John 1412` (March 2026) is a stale orphan with no sync config.

**Google Drive Metropolis vault** (`G:\My Drive\Obsidian\Metropolis Pt. 1--The Maverick And The Test`) is the SAME vault content as the Yoga vault, bridged through the **ThinkPad**: the ThinkPad runs Obsidian on the Metropolis folder (which lives in Google Drive) AND connects it to Obsidian Sync "John 14:12". So the ThinkPad dual-syncs Metropolis via BOTH Google Drive and Obsidian Sync, making it a bridge: Yoga (this PC) ↔ Obsidian Sync ↔ ThinkPad Metropolis ↔ Google Drive ↔ Metropolis (this PC). Proof: notes written only to the Yoga vault later appeared in Metropolis. **The bridge is INTERMITTENT** — it only flows when the ThinkPad is running Obsidian (earlier in the day, before the ThinkPad came online, a Yoga edit did NOT appear in Metropolis; once the ThinkPad bridged that evening, it did). ⚠️ This dual-sync on the ThinkPad's Metropolis folder is the conflict-risk setup (Drive + Obsidian Sync on one folder). Recommend the user pick ONE sync method for that folder. To avoid creating conflicts, WRITE to the Yoga vault only and let it propagate; don't edit both copies.

**Lesson:** Before writing to "the vault," check `obsidian.json` for the open vault on the current machine. Don't assume the Drive Metropolis path from [[user-berkeley-phd]] / CLAUDE-obsidian.md. Initially wrote class notes to the Drive vault by mistake; had to copy them to the Yoga vault.
