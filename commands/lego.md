---
name: lego
description: "Scans across Douglas's repos and finds general STRUCTURE TEMPLATES — reusable 'lego bricks' at every fidelity level (whole-app archetypes, page/dashboard shells, UI components, data patterns, server patterns, pipeline patterns, test/gate patterns, hook/guard patterns, skill/command patterns) — and records each as a durable, cited library entry so a future problem reuses tested, validated work instead of reinventing it. Runs a deterministic file-scan FIRST (enumerate candidates mechanically, before any narrative naming), gates on 'target repo unreadable/empty' before spending anything, records each brick as name / what-it-is / proven-instance-path / when-to-reuse / caveats, and writes a lean LEGO.md library at the repo root mapping to optional lego/<brick>.md detail files. Every brick MUST cite a REAL file path where the proven instance lives — never an invented example. De-dups against the existing LEGO.md (a brick already captured gets an 'also seen in' line, never a duplicate), and re-verifies the existing library's cited paths each pass — a dead path flips the brick to a date-stamped 'stale' status instead of silently rotting. READ-ONLY over the code it catalogs; writes only LEGO.md + lego/*.md. Use when Douglas says 'lego', 'find my reusable templates', 'catalog my structures', 'build the lego library', 'what bricks do I have', 'add this to the lego library', '/lego'."
---

# /lego [target] [--type <brick-type>] [--append] [--details]

Douglas keeps solving the same shapes across projects — a local live-server, a BUILD→ASSESS→GATE→DASH
pipeline, a dark-theme dashboard shell, an uncheatable physical gate, an atomic JSON writer. `lego` reads a
target's real files, recognizes those recurring shapes, and records each as a **brick**: a named, cited entry
in a `LEGO.md` library pointing at the single cleanest proven instance already in his code. The next time a
problem has that shape, he grabs the brick instead of rebuilding it.

The order is deliberate and copied from `/historian` and `/overlap`: **the "does this shape really exist here"
question is answered mechanically and by real file inspection FIRST** — enumerate the candidate files, read
excerpts, confirm the pattern is actually present — before any brick gets named or written. A brick with no
citable file is not a brick; it never ships. This skill catalogs what EXISTS; it never invents a template
Douglas might want.

## What this is NOT

- **Not `/overlap`.** `/overlap` compares ONE new thing Douglas is considering against his HARNESS
  (skills/hooks/memory) to decide build-new-vs-fold-in. `lego` mines his PROJECT CODE for reusable structural
  templates and records them — no build/fold decision, a different corpus, a different output.
- **Not `/historian`.** `/historian` reasons over the build-log's EVENT history to propose insights. `lego`
  reads the source files themselves to catalog structural patterns. It touches no event data.
- **Not `/tech-debt-audit`, `/solo-review`, `/panel-ultra-review`.** Those judge whether code is GOOD or
  BROKEN. `lego` is agnostic about quality per instance — it records the pattern and its known caveats so a
  future reuse starts informed. (A caveat line is not a review verdict; it's a reuse warning.)
- **Not `skill-creator` / `writing-skills`.** Those build new Claude Code skills. `lego` builds a reference
  library of code/UI structures, not skills.
- **Not a code generator.** `lego` writes only the LEGO.md library and optional `lego/<brick>.md` detail
  files. It never copies a brick's code into a new project — that's Douglas's move when he reaches for one.

## The brick-type taxonomy (the fidelity ladder)

A brick can be recorded at any fidelity, from a whole application down to a single UI primitive. This is the
menu of **what kinds of thing you can make a lego brick for** — scan for instances of each. Not every target
will have every type; record only the types you find a real citable instance of, and note which types were
looked for but not found.

**System / whole-app fidelity**

1. **whole-app-archetype** — a complete runnable system shape (a local live-server dashboard app, an agentic
   build-loop program, a CLI-driven generate→verify pipeline). The highest-fidelity brick: "this is the shape
   of a whole app of type X."
2. **local-server** — a stdlib/lightweight HTTP server pattern: static-serve + status endpoint, file-watch /
   live-reload, a whitelisted-job runner, a hidden-window launcher.
3. **pipeline** — a multi-stage data/build flow, especially the BUILD→ASSESS→GATE→DASH shape: stages that
   generate, measure, arbitrate, and publish.
4. **agentic-loop** — an autonomous generate→critique→regenerate engine where the loop lives in code (not
   turn-taking): worst-first prioritization, per-step isolation, measured re-assessment.

**Subsystem / architecture fidelity**

5. **gate-oracle** — an accept/reject arbiter: an uncheatable physical gate (measures ground truth, credits
   nothing by declared type), a multi-oracle cross-check, a read-only honest reporter that re-derives nothing.
6. **test-verification** — a reusable test STRUCTURE: property-based (Hypothesis) tests, mutation-proof
   boundary tests, golden-file regression, a synthetic-double pattern that tests logic without the heavy build.
7. **hook-guard** — a PreToolUse / guard script pattern: env-mutation guard, bulk-delete guard, secret-scan,
   path-traversal guard, authored-file protection.
8. **data-integrity** — atomic file IO (temp+fsync+os.replace), content-hash freshness/staleness manifests,
   content-addressed disk caches, state-sync.
9. **llm-integration** — an LLM classifier/router, a stdlib delegation-to-API runner (env-secret + winreg
   fallback, vision helpers, no SDK), a parallel fan-out caller.
10. **python-architecture** — a language-level structural pattern: sandboxed/AST-screened code exec, a
    feature-extractor, a face/attribute graph builder, a split data→sections→assemble module layout.
11. **3d-geometry** — a CAD/geometry pattern: GLB/PBR export with viewer-matched materials, tessellation,
    point-in-solid physical measurement, feature recognition.

**Page / component / UI fidelity**

12. **page-shell** — a whole-page HTML archetype: a self-contained dark-theme dashboard shell, a
    library/hub index page, a long-form explainer, a knowledge-graph page, a split-canvas editor.
13. **dashboard-structure** — a static-HTML dashboard ASSEMBLER (data.py + sections/ + assemble.py), a
    tabbed-view-with-global-search shell, a multi-source health dashboard.
14. **ui-component** — a single reusable UI primitive: card/image grid, KPI/stat-tile row, status-pill,
    tab system, filterable table, popover/tooltip, accordion, timeline, tag/pill chips, nav sidebar, hero,
    legend.
15. **3d-viewer** — an embedded interactive 3D/canvas viewer: THREE.js + GLTFLoader + OrbitControls with a
    part-list sidebar, a `<model-viewer>` PBR embed, a force-directed 3D knowledge graph, a headless
    WebGL screenshotter.
16. **theming** — a CSS design-token block (`:root` variables + `[data-theme=dark]` override), a
    before-paint theme guard that prevents dark-mode flash.
17. **serve-mode-embed** — a file:// vs served-mode guard/banner, an iframe view-switcher that composes
    standalone pages, an `?embed=1` chrome-strip convention that makes one file both a page and a widget.
18. **data-embedding** — an inline `<script>` JSON data blob hydrated client-side, so one self-contained
    file carries and renders its own dataset offline.

**Harness / meta fidelity**

19. **skill-command** — a reusable Claude Code skill/command structure: the gate-first + deterministic-scan +
    honest-report shape shared by `/historian`, `/overlap`, `/sage`, and this file itself.

If a scan surfaces a recurring shape that fits none of these 19, record it under a new type and say so in the
report — the taxonomy is meant to grow.

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

TARGET is one or more repo/folder roots to scan (default: the current working directory's project). Optional:
`--type <brick-type>` restricts the scan to one taxonomy type; `--append` adds to an existing LEGO.md rather
than proposing a fresh one; `--details` also writes a `lego/<brick>.md` detail file per brick (default: the
one-line library entries only). Resolve where LEGO.md should live: the **root of the primary scanned repo**
unless Douglas says otherwise. If ARGUMENTS names no target and it isn't obvious from the conversation, ask
which repo(s) to scan — don't guess.

### Step 1 — The gate (MANDATORY, before anything expensive)

Check the conditions that make the whole pass meaningless BEFORE spending the scan:

1. **Target unreadable or empty.** If a resolved target path does not exist, is not readable, or contains no
   source/markup files (only images/binaries/backups), say so plainly — *"target `<path>` is empty or
   unreadable — nothing to catalog"* — and STOP. Do not manufacture bricks from an empty folder.
2. **Nothing new since the existing library (on `--append`).** If a LEGO.md already exists and every shape you
   would surface already has a brick entry, say *"no new bricks — the library already covers what's here"* and
   STOP rather than re-recording what's already catalogued.

If the gate fires, that report IS the deliverable. Do not force a weak brick to look useful.

### Step 2 — Deterministic candidate scan FIRST (mechanical, before naming anything)

Enumerate the target's real files and group them into candidate buckets by the taxonomy — mechanically,
by filename/extension/directory and cheap `Grep` signals, before any brick is named:

- **Server/pipeline/loop/gate candidates** — `Glob`/`ls` for `*server*.py`, `*loop*.py`, `*watch*.py`,
  `gate*.py`, `accept*.py`, `assess*.py`, `forge*.py`, `*.pyw`; `Grep` for `HTTPServer`, `subprocess.Popen`,
  `def tick`, `os.replace`, `while True`.
- **Test/gate candidates** — `test_*.py`, a `tests/` dir, a `golden/` dir, a `.hypothesis/` dir; `Grep` for
  `@given`, `hypothesis`, `monkeypatch`, `golden`.
- **Hook/guard candidates** — `.claude/hooks/*.js`, `guard-*.js`, `block-*.js`, `protect-*.js` (in the repo OR
  the global `~/.claude/hooks/` if the repo's guards live there).
- **Data-integrity / llm / python-arch candidates** — `atomicio*.py`, `*cache*.py`, `freshness*.py`,
  `router*.py`, `gen*.py`, `safe_exec*.py`, `feature_*.py`; `Grep` for `fsync`, `sha256`, `ast.parse`,
  `__builtins__`, `winreg`.
- **Dashboard/viewer builders** — `build_*.py`, a `dashboard/` dir, `*.cjs` render scripts; `Grep` for
  `THREE`, `GLTFLoader`, `model-viewer`, `playwright`, `<style>`.
- **HTML page/UI/theme candidates** — `*.html` (skip `_backups/`); `Grep` for `:root`, `data-theme`,
  `grid-template-columns`, `class="kpi`, `pill`, `role="tab`, `location.protocol`, `?embed`, `JSON.parse`.

Output of Step 2 is a set of candidate files per taxonomy type. Anything with no candidate file is dropped
here, before a token is spent naming it. Cap total files opened; read EXCERPTS (`Grep` context, `Read` with
`offset`/`limit`), never dump whole files — a large repo will blow context otherwise. For a big multi-folder
scan, dispatch the per-folder digestion to subagents (their tool output stays in their context; only the
structured brick list comes back).

### Step 3 — Confirm each candidate is really the pattern, then record the brick

For each candidate that survives, open enough of the real file to CONFIRM the pattern is actually present
(not just a name collision), then record the brick in the exact contract below. A candidate whose file does
not actually implement the pattern is dropped with a one-line reason (kept in the run log, not recorded).

**The inclusion bar (confirmed still means it must earn a slot):** a brick ships only when a future problem
would actually reach for it — the shape RECURS (a second real instance exists, in this repo or another) OR a
single instance is clearly generic beyond its home project. A confirmed one-off welded to its project's
specifics goes in the report as *"observed, below the bar"* with one line on why, and stays out of the
library. The library only keeps its value while it stays lean enough to actually get read.

**Brick record contract (every field required except ALSO SEEN IN):**

- **NAME** — short kebab-case identifier.
- **TYPE** — which of the 19 taxonomy types it is.
- **WHAT** — one sentence: what the structural pattern IS.
- **PROVEN INSTANCE** — the single best REAL absolute file path that is the cleanest example. This field is
  load-bearing: it MUST be a file that exists and actually implements the pattern. No invented paths, ever.
- **WHEN TO REUSE** — one sentence: the future situation where you'd reach for this brick.
- **CAVEATS** — one line: known gotchas / reuse warnings, or "none noted."
- **STATUS** — date-stamped, one of exactly three values: `proven <date>` (cited file existence-checked and
  pattern-confirmed on that date — the default), `caution <date>` (the caveat is serious enough to re-check
  before any reuse), `stale <date>` (the cited path no longer exists — see Step 4). Three values only; a
  status earns its place by changing reuse behavior, so no finer gradations.
- **ALSO SEEN IN** — up to 2 other real paths where the same pattern recurs (optional; this is also where a
  de-dup match lands, see Step 4).

### Step 4 — Re-verify, then de-duplicate against the existing library

**Re-verify first (any run that touches an existing LEGO.md, --append or otherwise):** existence-check every
recorded PROVEN INSTANCE path mechanically (a cheap `ls`/Glob pass — no file reading). A path that no longer
exists means the brick has rotted: repoint PROVEN INSTANCE to a still-existing ALSO SEEN IN path if one
survives the same check, otherwise flip the brick's STATUS to `stale <today>`. Never silently delete a rotted
brick — the entry still records that the shape was once proven, and where; removal is Douglas's call (surfaced
in the Step 6 report). Refresh the STATUS date on every brick whose path checks out.

**Then a cheap drift check on every surviving path (existence alone is not proof the pattern is still there).**
A file that still exists but has been refactored so the pattern no longer lives in it is the most dangerous
kind of stale — the citation reads `proven` yet points at code that no longer backs the claim, so a future
reuse trusts a brick that has quietly become a lie (the same failure as a runbook citing a deploy gate that
was removed months ago). Existence-checking the path does not catch this. So for each path that exists, run
ONE cheap `Grep` for the brick's defining signature — the same Step 2 signal that surfaced it (e.g. `HTTPServer`
for a local-server brick, `os.replace` for atomic-IO, `@given` for a property-test brick, `data-theme` for a
theming brick) — and if the file exists but the signature is gone, flip STATUS to `caution <today> — path
exists but pattern signature absent, confirm before reuse` rather than leaving it `proven`. This stays cheap
(one existence check + one signature grep per brick, still no whole-file reads), yet turns the re-verify into a
real sync signal that catches doc-vs-code drift and outright deletion alike. A signature that still matches earns
the refreshed `proven <today>`.

If a LEGO.md already exists (or two candidates in this run are the same pattern), do NOT write a second brick
for the same shape. Instead add an **"also seen in"** line to the existing brick citing the new path. A brick
already captured gets enriched with the new instance, never duplicated. Match on TYPE + normalized NAME +
pattern description, the same discipline as `/historian`'s de-dup and `/overlap`'s composite-overlap check.

### Step 5 — Write the library (output contract)

- **`LEGO.md` at the primary scanned repo's root** — the lean library index. Grouped by fidelity band (System
  / Subsystem / UI / Harness), each brick a compact block with the contract fields above. A short header states
  what was scanned, when, and which taxonomy types were looked for but not found.
- **`lego/<brick>.md` detail files (only on `--details`, or for a brick complex enough to warrant it)** — the
  deeper reference for one brick: the full pattern, the key code shape (a short excerpt, not the whole file),
  every known caveat, and the reuse recipe. LEGO.md links to it.
- **Never overwrite a hand-edited LEGO.md blindly** — on `--append`, merge (add new bricks + "also seen in"
  lines), leaving existing curated entries intact. Back up before a destructive rewrite per the file-safety
  rule.

### Step 6 — Report

- **Gate outcome first** if it fired (that IS the report).
- **Taxonomy coverage**: how many of the 19 types got at least one brick, and which types were looked for but
  found no instance in the scanned targets (stated honestly — an absent instance is not a failure).
- **Bricks recorded**, grouped by fidelity band, each with its proven-instance path.
- **De-dups**: any brick that got an "also seen in" line rather than a new entry.
- **Library health** (whenever an existing LEGO.md was touched): bricks re-verified clean, repointed, flipped
  to `stale` (path gone), or flipped to `caution` on drift (path exists but the pattern signature is gone) this
  run — stale bricks queued for Douglas's delete-or-repoint call, drifted ones for a confirm-before-reuse check.
- **Below the bar**: confirmed shapes observed but kept out of the library (Step 3's inclusion bar), one line
  each on why.
- **A "decisions Douglas should review" list** — judgment calls the scan made that he might overrule: a brick
  whose "best proven instance" was one of several near-equal candidates; a pattern that recurs so much it might
  deserve extraction into a shared module; a caveat that reads more like a real bug than a reuse warning; a
  type with no instance that he might expect to have one; a brick that spans two types.
- **Full absolute paths** of every file created/updated, per the standing Files-list convention, tagged
  NEW/UPDATED with what changed.

## Safety constraints (every run)

- **READ-ONLY over the code it catalogs.** `lego` reads source/markup to recognize patterns and writes exactly
  two things: `LEGO.md` and optional `lego/*.md`. It never edits, refactors, or runs the code under study.
- **Every brick cites a real path.** A brick with no citable, existing, pattern-confirming file does not ship.
  This is the hard line — the whole value of the library is that every entry points at tested, working code.
- **No fabrication.** Do not invent a template Douglas "should" have, do not cite a path you did not confirm
  exists, do not upgrade a name-match into a confirmed pattern without reading the file (Step 3).
- **No commits, no web.** `lego` writes local files and reports — never `git commit`/`git push`, never needs
  the web.
- **Stay scoped to the targets.** No touching unrelated files, processes, or shared state.

## Voice

LEGO.md and any `lego/*.md` are reference docs Douglas will keep and read — publishable prose. No "it's X, not
Y" antithesis anywhere. State each brick's positive claim and stop.

---

*Tracked copy: also save this file to `claude-global-config/commands/lego.md` (per the skills-are-tracked
convention) after a NASA scrub.*
