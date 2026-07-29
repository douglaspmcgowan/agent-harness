---
name: ui-feature-ledger
description: "Feature-continuity ledger for an app's OWN UI across rebuilds. Stops the silent-removal failure mode: a previously-approved control (a play-by-play panel, keep/reject buttons) vanishes during an impeccable/design/direct-edit pass because the regenerating agent never knew it was load-bearing (4 mined cases). /ui-feature-ledger init enumerates every interactive control from the LIVE DOM via headless Playwright into a FEATURES.md next to the app; before any subsequent edit the controls are snapshotted, after the edit re-snapshotted and diffed, and any removal the current request did not name BLOCKS the done-claim with the missing controls listed. New user-requested elements append to the ledger automatically. Runs unprompted inside impeccable, /design, and direct UI-edit flows; manual via '/ui-feature-ledger init' and '/ui-feature-ledger check'. Use when Douglas says 'ledger this app', 'init the feature ledger', 'check the ledger', 'did we lose any buttons', '/ui-feature-ledger'."
---

# /ui-feature-ledger [init|check] [app-path]

Every rebuild of an existing UI re-litigates which features survive. This skill makes survival the default:
the ledger (`FEATURES.md`, living next to the app) is the durable record of every approved interactive
control, and an edit pass ends only after a mechanical DOM diff proves nothing left the page that the current
request left unnamed. The agent's memory of what the app had is replaced by a file plus a snapshot diff.

## What this is NOT

- **Not `/replicate`.** `/replicate` builds a parity checklist against an EXTERNAL reference app and verifies
  the target reaches it. This skill tracks continuity of the SAME app against its own past: yesterday's
  approved buttons must still exist after today's rebuild. Different reference, different question.
- **Not the CLAUDE.md surgical-change rule.** That rule is behavioral prose; sessions violate it under
  regeneration pressure (4 mined cases). This skill is the enforcement artifact: a file-based ledger plus a
  before/after DOM diff that fires whether or not the session remembered the rule.
- **Not a visual-regression tool.** Pixel diffs (Percy, screenshot compare) catch styling drift. This checks
  EXISTENCE of interactive controls; a button restyled beyond recognition passes, a button deleted fails.
- **Not a review skill.** It renders no judgment on whether the UI is good — `/design-review` and impeccable
  `critique` do that. This answers one narrow question: is every ledgered control still present.

## Gate — when NOT to run

Skip (and say so in one line) when ANY of these hold:

1. **The app is brand-new this session** — nothing approved yet, nothing to protect. Run `init` at the END
   of the session that ships it, so the next session inherits a ledger.
2. **The edit touches no UI surface** — backend, docs, data, config. No DOM, no ledger.
3. **Douglas explicitly asked for a teardown or rewrite of named features** — removals he named are
   authorized by definition; only run the check to confirm nothing BEYOND the named set vanished.
4. **The app can't render headlessly** (needs auth, a live device, a licensed runtime) — say so and fall
   back to a static-source scan (grep for `<button`, `onclick`, `addEventListener`, `<input`, `<select`)
   with an honest note that a static scan undercounts dynamically-created controls.

## Procedure

### Step 1 — `init`: enumerate the live DOM into the ledger

Launch the app headlessly (Playwright is the standing default for anything browser-visible) and enumerate
every interactive control: buttons, links with handlers, inputs, selects, textareas, checkboxes/toggles,
elements with `onclick`/`role="button"`. One snapshot line per control — stable key first:

```js
// snapshot: node -e "..." or a Playwright script; key = tag#id | tag[aria-label] | tag"visible text"
const controls = await page.$$eval(
  'button, a[href], a[onclick], input, select, textarea, [onclick], [role="button"], [role="tab"]',
  els => els.map(e => `${e.tagName.toLowerCase()}${e.id ? '#' + e.id : ''}` +
    `${e.getAttribute('aria-label') ? '[' + e.getAttribute('aria-label') + ']' : ''}` +
    `"${(e.textContent || e.value || '').trim().slice(0, 40)}"`));
```

Why raw-DOM `$$eval` and not Playwright's `toMatchAriaSnapshot` (the canonical snapshot API): that assertion is order-sensitive (a reorder false-fails) and reads the accessibility tree, which drops `aria-hidden` / `display:none` nodes — exactly the tab-panel and modal controls this ledger most needs to keep tracking. Raw DOM gives order-insensitive existence over hidden controls too. The trade is that the ARIA tree would catch role/label regressions the DOM key misses; that is out of scope here (existence only).

**Load-time blind spot — state honesty.** A single at-load snapshot only sees controls already in the DOM. Controls a framework builds *on interaction* (a modal whose markup mounts on open, a lazy tab panel) are absent until you drive that state, so the ledger silently undercounts them. Before snapshotting, cheaply open the obvious always-present entry points (each top-level tab, a primary modal trigger) so their controls enter the DOM first; for anything gated behind auth/data you can't reach, note in the ledger header which states went un-snapshotted rather than imply the count is complete. (Full state-aware capture stays the parked future-work item below — this step only forbids claiming completeness the snapshot didn't earn.)

Write `FEATURES.md` NEXT TO the app (same folder as its entry HTML/root): a header naming the app + entry
URL/file + snapshot command, then one `- ` line per control. When the requesting quote/date is known from
the session ("add keep/reject buttons", 2026-07-19), append it in parentheses; unknown origins get
`(pre-ledger)`. Verify init by re-running the snapshot and confirming the count matches the ledger.

### Step 2 — pre-edit snapshot (automatic, before any edit to a ledgered UI)

Before the first Edit/Write/regeneration touching an app that has a `FEATURES.md` beside it: run the same
snapshot, save to a temp file (`FEATURES.pre.txt` in the app folder, gitignored/deleted after). If the
pre-edit snapshot already disagrees with `FEATURES.md`, STOP and report the drift first — the ledger is
stale and diffing against a stale baseline proves nothing.

### Step 3 — post-edit diff (`check`) — the blocking step

After the edit, re-snapshot and diff against the pre-edit snapshot (or against `FEATURES.md` when no
pre-edit snapshot exists, e.g. a manual `check`). Diff **by per-key count, not set membership**: a plain
set/`uniq` diff collapses identical keys, so removing one of two `button"Delete"` controls (same tag, no
id/aria-label → identical key) produces no change and the regression escapes. Tally each key's occurrences
in both snapshots and flag any key whose count dropped; `sort | uniq -c` on each snapshot, then diff the
counted lines, is enough.

- **Removals named in the current request** → fine; delete their lines from `FEATURES.md` with a dated
  `(removed: <request quote>)` note in the commit/report.
- **Removals the request did NOT name** → **BLOCK the done-claim.** List every missing control verbatim,
  restore them (or ask Douglas, one line, if restoration conflicts with the requested change), re-run the
  diff, and only then report done. A done-claim with an unexplained missing control is a failed check.
- **Additions Douglas requested** → append to `FEATURES.md` with the requesting quote + date, same pass.
- **Additions nobody requested** → flag in one line (surgical-change rule); do not silently ledger them.

### Step 4 — wiring (so it runs unprompted)

When invoked from an impeccable pass, `/design`, or any direct edit of an app that has a `FEATURES.md`,
Steps 2–3 run automatically — no manual `/ui-feature-ledger check` needed. Sibling flows should treat "app
folder contains FEATURES.md" as the trigger condition. Apps without a ledger get a one-line nudge at the
end of the pass: "no FEATURES.md here — run /ui-feature-ledger init to protect this UI's controls."

### Step 5 — verify the check itself (once per app, after init)

Prove the tripwire works: in a scratch copy of the entry file, delete one ledgered button, run `check`, and
assert it reports exactly that control missing. Restore the copy. A check that has never caught a planted
deletion is unverified; say which app(s) have passed this and which haven't.

## Safety constraints (apply every run, no exceptions)

- **Writes ONLY `FEATURES.md` (+ its temp `FEATURES.pre.txt`).** `init` and `check` never edit the app.
  Restoration of a missing control in Step 3 happens in the surrounding edit pass, under its normal
  permissions — this skill reports and blocks; the fixing is the editing session's job.
- **The ledger is an authored file once Douglas hand-edits it.** Standing file-safety rule applies: never
  regenerate/overwrite a hand-edited `FEATURES.md` wholesale — back up to `_backups/` first, then apply
  line-level edits only.
- **No fabricated provenance.** A requesting quote/date goes in only when actually known from the session
  or logs; otherwise `(pre-ledger)`. Never invent who asked for a control.
- **Headless only, local only.** Playwright drives the local app file/port; no external URLs, no egress.
- **No commits, no elevated permissions.** A blocked done-claim is a report to Douglas, never a reason to
  bypass a permission gate or auto-commit a restoration.

## Final report (honest register)

- **Verdict first**: `check` PASS (all N ledgered controls present) / BLOCKED (list each missing control
  verbatim + which request would have had to name it) / DRIFT (ledger vs pre-edit mismatch, resolve first).
- **Ledger delta this pass**: lines added (with quotes/dates), lines removed (with authorizing request),
  lines unchanged — counts, so Douglas sees movement at a glance.
- **What the check does NOT prove**: controls still exist; their handlers may still be broken. Behavior
  verification stays with `/verify` / `/user` / Playwright functional tests. Never report "the UI is
  intact" — report "all ledgered controls are present."
- Full absolute paths of `FEATURES.md` and the app entry file, NEW/UPDATED tagged.

*This is a solid v1 (spec from the 2026-07-21 friction mining, 4 evidence cases). `/ultraskill improve
ui-feature-ledger` can deepen it: richer stable keys, state-aware snapshots (controls behind tabs/modals),
and a PreToolUse hook variant that gates the edit itself.*

---

*Tracked copy: also save this file to `claude-global-config/commands/ui-feature-ledger.md` (per the
skills-are-tracked convention) after a NASA scrub.*
