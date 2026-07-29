---
name: docket
description: "Send a brief, a review item, or a decision into Douglas's review board with the correct schema, so it lands in a persistent queue he can act on (from his phone) instead of being buried in chat. PRIMARY surface is the cloud board vault-review-mobile (https://vault-review-mobile.vercel.app) — it now renders all THREE kinds (briefs with reflowed markdown + tables, reviews, and the rich decision types tradeoff/reversibility/reasoning-tree/diff/critique), groups by project or by kind, and syncs read-state across devices. The local mirror (:8471) now runs the SAME app (same UI + enqueue.js, local-file store, localhost-bound) for NASA-sensitive content. This is the routing front door for the standing auto-route rule ([[feedback_auto_route_workbench]]): use it AUTOMATICALLY, without being asked, whenever you (a) produce a brief/report/recon/explainer, or (b) have 5+ (more than 4) distinct items to approve/reject/edit or questions/options to decide among. MANDATORY sensitivity gate: only public/personal/NASA-cleared content goes to the cloud; NASA/CUI/ITAR content stays LOCAL-only (:8471) and is never pushed. Explicit asks: 'send this to my review board / phone / reviewer app / briefs', 'route this for review', 'queue this decision', 'docket this', '/docket' (formerly 'tsa this' / '/tsa'). NOT for a single quick approve/reject or a one-question decision (keep those in chat); NOT for generating HTML design variants (that is the /gallery skill)."
---

# /docket [brief|review|decision] [what to send]

> Formerly `/tsa`. It dockets work — files each brief/review/decision onto a persistent queue Douglas can
> adjudicate from his phone — instead of leaving it buried in chat.

Chat is a bad queue. A brief or a five-item review buried in a long turn is easy for Douglas to lose. The
**cloud board `vault-review-mobile`** (https://vault-review-mobile.vercel.app) is the built home: a
phone-accessible, mark-read/archive queue that renders all three kinds, groups by project or by kind, and
syncs across devices. `/docket` is the front door: it takes a brief, a batch of review items, or a decision,
shapes it to the right schema, tags its project, and pushes it so Douglas can triage from anywhere.

## GATE — sensitivity (run FIRST, every time)

The cloud board lives on Vercel: **anything pushed there leaves this machine.** `enqueue.js` now ROUTES by a
`sensitive` flag, **default sensitive (fail-safe)**, so a forgotten classification fails safe (stays local)
instead of leaking. Classify, then pick the flag:

- **Public / personal / NASA-cleared** → pass **`--public`**. Routes to the **cloud** (and mirrors to the
  local board, so local stays the full superset). This covers most briefs, reviews, and decisions from
  personal, harness, research, and cleared-project work.
- **NASA-internal / CUI / ITAR** → **no flag** (or `--sensitive`). The card is sensitive by default and
  routes to the **local mirror only** (`http://127.0.0.1:8471`); it is never networked. When unsure, omit
  `--public` — the default keeps it local.
- **Enforced, not just convention (defense in depth):** a sensitive card aimed at any non-loopback URL is
  REFUSED by `enqueue.js` before any network call, and the cloud board itself refuses to store any
  `sensitive:true` card at ingestion. Forgetting `--public` on public content just means it lands local —
  re-push with `--public`.

## When to use it (and when not)

Route automatically, per the standing directive in `MEMORY.md` — do not wait to be asked:

- **A brief** — anything the "Briefs → Obsidian" rule produces (a substantial brief, report, recon,
  explainer). Write it to the vault as usual, AND `/docket` it as a `brief`. Pass the note's `src` path — the
  cloud inlines the file into the card at push time (so it renders even though the cloud can't read local
  paths) and keeps the filepath as a copyable chip.
- **A batch of 5+ things to review** (approve / reject / edit / answer) → `review` items.
- **A batch of 5+ questions or options to decide among** → a `decision` item (pick the richest fitting type).

Do **not** use it for: a single quick approve/reject or a one-question decision (keep those inline); design
variants (that is **`/gallery`**); a plain answer to a plain question.

## Procedure (cloud = default)

1. **GATE** on sensitivity (above). Public/cleared → add `--public` to the push (step 5). Sensitive → no
   flag (default routes it local). Both use the SAME command; only the `--public` flag differs.
2. **Reuse a canonical project — don't spawn near-dupes.** Before assigning a project/set, list what already
   exists and match against it:
   ```
   C:/Users/dmcgowa2/tools/nodejs/node.exe "C:/Users/dmcgowa2/Documents/Claude NASA Folder/vault-review-mobile/enqueue.js" --groups
   ```
   Pick the existing project name (and set) when the work belongs to one; only coin a new name when it's
   genuinely new. Keep names SHORT (a label, not a sentence — long sources become ugly project names).
2b. **UPDATE an existing card, don't always add a new one.** Many projects accrue a *living* brief/decision
   that should be refreshed in place rather than re-uploaded as a duplicate. When the item you're about to push
   is a newer version of one already on the board, find its id and reuse it — a same-id push overwrites in
   place (and, since it was never answered, it stays visible with the new content):
   ```
   C:/Users/dmcgowa2/tools/nodejs/node.exe ".../vault-review-mobile/enqueue.js" --list "<project>"
   # then re-push with that id:
   C:/Users/dmcgowa2/tools/nodejs/node.exe ".../vault-review-mobile/enqueue.js" --id <existing-id> --kind brief --title "..." ...
   ```
   Default to UPDATE for a standing/living brief (a PRD, a status page, a running decision) and to ADD for a
   genuinely new item. (`--list` prints `kind · project/set · id · title`; `--list` with no arg lists all.)
3. **Pick the type and build the item JSON.** Match the ask to `brief`, `review`, or `decision`; assemble per
   the schema below. For a batch, prefer **one `review` item per independently-decidable thing** — but merge
   near-duplicate judgments into one card (a flooded queue trains skimming; oversight collapses when the queue
   outgrows the reviewer). Tag the group with `"project"` and (optionally) `"set"` fields, or
   `--project`/`--set` flags. Write JSON to a temp `.json` file (heredoc/stdin is fiddly in PowerShell here).
   - **Every card must be decidable from the card alone.** Douglas reads it on his phone without the
     transcript. Each `review`/`decision` card carries: your recommendation + a one-line why in the
     `description`, and — when options differ in consequence — what picking each option commits to. A card
     that needs the chat to understand is a bad card; rewrite it before pushing.
   - **`"blocking": true` ONLY when the card gates work this session still intends to do.** Default false.
     A blocked queue full of non-gating cards is noise that hides the real gate.
   - **Stable `"id"` for any card a later run might push again.** The auto-generated id folds in the push
     timestamp, so re-running this step — a resumed session, a keep-going re-fire, a crash after the push but
     before the queue flip — mints a fresh id and files a *duplicate* card. Set an explicit content-derived
     `"id"` (e.g. `<slug of title>--<hash of the stable body/options>`) on anything re-pushable; a repeat push
     with the same id overwrites the card in place, so the queue holds one card instead of two. Keep the id
     off the clock — derive it from content only.
4. **Offload if heavy.** Many items / long bodies / a source re-read → dispatch a **sonnet low-effort
   subagent** to build the JSON and run the push, so it stays off the main thread. Hand it the source paths,
   target type + schema, the absolute command below, and "print the returned id(s)". (On a GEN/NASA-keyed
   session, `agent-model-guard` requires an explicit `model` — use `sonnet`, or `opus` low-effort.)
5. **Push** (one card per invocation — loop per item for a batch). Add **`--public`** for cloud-bound
   (public/cleared) content; omit it for sensitive content (routes local by default):
   ```
   C:/Users/dmcgowa2/tools/nodejs/node.exe "C:/Users/dmcgowa2/Documents/Claude NASA Folder/vault-review-mobile/enqueue.js" --public --file <tmp.json>
   ```
   It resolves the passcode from `.passcode.txt` beside it. `--public` → cloud (+ local mirror); default →
   local mirror. Prints `pushed 1 <public|SENSITIVE> card -> <id>  @ <url>`. (Direct fields also work: `--title`, `-d`, `--options "a,b"`,
   `--source "proj: set"`, `--project`, `--set`, `--link <url>`, `--blocking`, `--kind brief|decision`,
   `--id <id>` (update in place — see 2b), `--list [project]` (find an id); `--selftest` runs an offline check.)
   - **Verify every push.** Check for the `pushed 1 card -> <id>` line per item; on a batch, tally
     succeeded vs failed and retry or fall back (local store, or chat) for the failures. Never report
     "docketed" without the returned id(s) — a silent drop is the worst failure this skill has.
6. **Report** the id(s) and the URL: **https://vault-review-mobile.vercel.app** (Douglas triages from his
   phone). Clean up the temp `.json`.
7. **Checkpoint what's awaiting Douglas.** A pushed card is a suspended decision; the session (or its
   successor) must be able to resume when he answers. For any card whose answer the work depends on, add a
   `[?]` line to the session's WORK_QUEUE / CURRENT-TASK — `[?] docket <id> — <title>` — so the keep-going
   loop parks it and a resumed session knows exactly what is outstanding and where the answer lands. Flip
   it when the board shows his answer — and read any comment he left before flipping: a rejection with a
   reason is a course correction to act on, and a comment with no option picked is the whole answer.

## Local-only path (:8471 mirror, for NASA-SENSITIVE content)

For NASA-internal / CUI / ITAR content that must NOT leave the machine, the **local mirror** is now the
DEFAULT route — the *same* board (same UI, same `enqueue.js`, same schemas as the cloud), served by
`local-server.js` on `http://127.0.0.1:8471`, backed by an on-disk store (`~/.docket-local`) that never
touches the network. A card is sensitive by default, so pushing with **no `--public` flag** routes it here
automatically. An explicit `--url http://127.0.0.1:8471` still works and is equivalent:
```
C:/Users/dmcgowa2/tools/nodejs/node.exe "C:/Users/dmcgowa2/Documents/Claude NASA Folder/vault-review-mobile/enqueue.js" --file <tmp.json>
# receive Douglas's decisions from the local board the same way:
C:/Users/dmcgowa2/tools/nodejs/node.exe ".../vault-review-mobile/enqueue.js" --url http://127.0.0.1:8471 --pull
```
`--list`, `--groups`, `--pull`, `--id` all work against `--url http://127.0.0.1:8471` exactly as against the
cloud. The old reviewer/decide/briefs workbench is retired.

**Durability + auto-sync (the `DocketDaemon` logon task).** The mirror no longer needs manual starting: a
Windows Scheduled Task `DocketDaemon` runs `docket-daemon.js` at every logon (hidden, via
`docket-daemon.vbs`, logging to `%LOCALAPPDATA%\docket-daemon.log`). The daemon (1) keeps `local-server.js`
alive — respawns it with backoff if it dies — and (2) runs `sync-cloud.js` every 15 min: it pushes the
**explicitly-public** local cards (`sensitive===false`) up to the cloud and pulls the cloud's decisions back
into the local store. So the local store is the single source of truth (superset); the cloud auto-narrows to
the non-sensitive subset. The sync filter is STRICT — unmarked/legacy cards (no `sensitive` field) are treated
as sensitive and withheld, so nothing pre-flag ever leaks. Manual controls: `Start-ScheduledTask DocketDaemon`
/ `Stop-ScheduledTask DocketDaemon`; one-off sync `node vault-review-mobile/sync-cloud.js`.

## Schemas (extra keys are dropped/validated)

- **brief** — `{ "title": <str>, "format": "md"|"html" (default md), and EXACTLY ONE of "body": <inline str>
  OR "src": <absolute path to a .md/.html file>, "source"?: <str>, "project"?: <str>, "set"?: <str>,
  "tags"?: [{"text","tone"?}], "blocking"?: bool, "kind": "brief" }`. Pass `src` for a vault note — the cloud
  inlines it and keeps the filepath chip. Hard-wrapped markdown tables in the body are auto-rejoined so they
  render (the reflow + table-unwrap fix).
- **review** — `{ "title": <str>, "description"?: <str>, "options"?: [str,…] (default ["Approve","Reject"]),
  "project"?: <str>, "set"?: <str>, "blocking"?: bool, "source"?: <str> }`. One item per thing to judge.
  Douglas can also pick NO option and just leave a comment.
- **decision** — `{ "title": <str>, "kind": "decision", "type": <REQUIRED, one of: option-select | tradeoff |
  reversibility | reasoning-tree | diff | critique>, + that type's fields, "project"?, "set"?, "blocking"?:
  bool }`. All six types now render on the cloud. Fields per type: `option-select` → `options`; `tradeoff` →
  `options`[{id,label}] + `criteria`[{id,label}] + `cells`[{option,criterion,stance:supports|against|neutral}];
  `reversibility` → `door: one-way|two-way` + `cost_to_reverse` + `consequences`[str]; `diff` → `before` +
  `after` + `lang`; `reasoning-tree` → `nodes`[{id,label,parent?,status:active|pruned|chosen}]; `critique` →
  `artifact`{kind:text|image, content}. For generated HTML options use `/gallery`.

## "Tell me more" comes BACK from the phone as feedback

Each card has a **Tell me more** button. A tap now submits it **like any other feedback** (`POST /api/submit`
`{id, action:'more', notes?}`): the card **clears from the board** and a result with `"action":"more"` is
recorded — the action for that feedback is *remake the card fuller*. Pull the results with `enqueue.js --pull`
(the receive verb, over `GET /api/sync?op=pull`; `--pull <id>` filters by id substring); **any result
whose `action === 'more'` is an expand request** (printed as `MORE — remake fuller`). Process each: regenerate
that card's `description`/`sections`/`body` with more depth (honoring its `notes` if present) and push the
fuller version via `enqueue.js` under a **NEW id** — the original id is now answered, so it stays hidden while
the fresh, richer card appears on the board. (Do NOT reuse the old id for a `more` re-push: an answered id
stays filtered out and the fuller card would never surface.)

## Requirements & constraints

- **Zero new dependencies** — ONE client (`vault-review-mobile/enqueue.js`) serves both boards; sensitivity
  picks the route (`--public` → cloud + mirror, default → local). Do not add a package or a third enqueue path.
- **Sensitivity is load-bearing but now enforced in code** — a card is sensitive by DEFAULT (fail-safe), and
  two guards back the gate: `enqueue.js` REFUSES to send a sensitive card to any non-loopback URL, and the
  cloud board REFUSES to store any `sensitive:true` card at ingestion (`api/sync.js`). `block-nasa-web-egress`
  still guards only the WebFetch/WebSearch tools, not this push — so the flag + guards are what protect it.
  Classify honestly, add `--public` only for cleared content, and never write a secret into an item body.
- **SentinelOne caveat** — `enqueue.js`/`sync.js` read the passcode and upload to Vercel, which the NASA EDR
  may flag as exfiltration and quarantine. They live in git (github.com/douglaspmcgowan/vault-review-mobile) —
  re-checkout if a file vanishes. This is why the push is a manual CLI call, never a scheduled task.

## Wiring (where this lives)

- **Cloud board (PRIMARY):** `C:\Users\dmcgowa2\Documents\Claude NASA Folder\vault-review-mobile\enqueue.js`
  → https://vault-review-mobile.vercel.app. Renders briefs/reviews/all decision types; by-project ↔ by-kind
  lenses; cross-device read-state; project/set rename via the app's edit buttons or `sync.js ?op=rename`.
- **Local mirror (SENSITIVE board):** `…\vault-review-mobile\local-server.js` on `http://127.0.0.1:8471`
  — the SAME `public/index.html` + `api/*` handlers as the cloud, backed by a local-file store
  (`~/.docket-local`), localhost-bound. Reach it with `enqueue.js --url http://127.0.0.1:8471`. This is
  where NASA-internal/CUI/ITAR cards go. (The old reviewer/decide/briefs workbench is retired.)
- Phone "Tell me more" now arrives as a pulled result with `action:'more'` (see the section above) — remake
  the card fuller under a new id. (The old `tickets.json`/`op=tickets` path is retired.)
- **Codex** uses the same board the same way — send via `enqueue.js` push, receive via `enqueue.js --pull`,
  auth via the `REVIEW_SECRET` env var (no `.passcode.txt` in its sandbox). Hand a Codex agent the
  self-contained protocol at `…\vault-review-mobile\CODEX.md`; the dispatcher injects `REVIEW_SECRET`.
- Standing rule that triggers this automatically: `MEMORY.md` top directive + [[feedback_auto_route_workbench]].
- Sibling: `/gallery` (design-options → decision). App roster: [[reference_local_apps]].
