---
name: declutter
description: "Architecture-deepening pass for a codebase — find shallow modules (tiny units behind big, leaky interfaces the way AI agents accrete them) and propose turning them into DEEP modules (lots of functionality behind a simple interface), using Ousterhout's A Philosophy of Software Design vocabulary and Matt Pocock's improve-codebase-architecture method. Scans git hot-spots + walks code for friction (module-bouncing, shallow interfaces, poor locality, leaky seams, untested paths, Ousterhout's complexity red-flags), scores deepening opportunities by leverage, and emits a self-contained HTML report with before/after shapes and recommendation-strength badges. Reviews and proposes; it does NOT auto-refactor. Orchestrates rather than duplicates: routes a friction point that is really a perf issue to /hone, a correctness bug to systematic-debugging, a UI/IA restructure to /design, a full debt catalog to /tech-debt-audit, verification to requesting-code-review. Use when Douglas says 'declutter', 'de-slop this codebase', 'improve the architecture', 'find shallow modules', 'is this codebase getting sloppy', 'deepening opportunities', 'run an architecture review', '/declutter'."
---

# /declutter [target] [--report-only]

Complexity is not lines of code — it is the effort it takes you, or an agent, to safely change the code.
This command finds where that effort concentrates and proposes structural changes that lower it:
**shallow modules made deep**. It reads and proposes; it never refactors on its own. Its output is a
ranked, visual report of deepening opportunities, each traced to a named symptom, so Douglas decides which
(if any) are worth the change.

The AI-era reason this exists: coding agents take the path of least resistance and copy the nearest
pattern, so they accrete *shallow* modules — many tiny units with wide, leaky interfaces. An agent then
has to spelunk across all of them to make one correct change, so the same shallowness that slowed the
first change compounds every change after. Deep modules hide functionality behind a simple interface, and
a simple interface is exactly what both a human and an agent can work through without reading the
implementation.

## Deviation clause

The staged process below is the well-reasoned default, not a straitjacket. If a specific codebase makes a
different move clearly right — skip the HTML report for a two-file repo, jump straight to a handoff because
the "architecture" problem is really a single perf hot-loop — surface the divergence and the reason to
Douglas for his call, rather than silently following the steps or silently going your own way.

## What this is NOT

- **Not `/tech-debt-audit`.** That catalogs debt broadly (dead code, stale deps, TODOs, duplication, weak
  tests) across a whole surface. `/declutter` is narrower and deeper: it reasons only about module DEPTH and
  interface design through one lens (Ousterhout/Pocock), and hands the general catalog to
  `/tech-debt-audit`. Run that for breadth, this for structural depth.
- **Not `/hone`.** `/hone` measures and improves speed/memory. `/declutter` never measures runtime; it
  reasons about change-cost and design. If a friction point is really "this is slow," `/declutter` DEFERS to
  `/hone` rather than guessing at a perf fix.
- **Not `/design` / `/design-review`.** Those own product IA / UX / visual structure of a UI surface.
  `/declutter` owns the *code's* module structure. A friction point that is really "this screen's information
  architecture is wrong" is handed to `/design`.
- **Not `/spar`.** `/spar` attacks a running target to find correctness bugs and fixes them. `/declutter`
  doesn't run the target or hunt bugs; a correctness smell it notices is routed to `systematic-debugging`.
- **Not an auto-refactorer.** Ousterhout's whole point is that design is judgment. This surfaces and ranks;
  the human picks. `--report-only` is the default posture; any actual edit is opt-in, per-candidate, and
  isolated (see Safety).

## Core vocabulary (use these exactly; do not drift)

Enforce this vocabulary in every finding and in the report. Do not substitute the fuzzy words in
parentheses — precision here is the point, and the loose synonyms are where the analysis goes soft.

- **Module** — a unit of code organization (a file, class, or package). *(not "component / service")*
- **Interface** — everything a caller must understand to use a module: its signatures AND its informal
  contract (ordering, side effects, what it assumes). *(not "API / surface")*
- **Depth** — benefit ÷ cost: how much functionality a module hides behind how simple an interface. Deep =
  much hidden behind little. Shallow = interface nearly as complex as the implementation. *(the whole game)*
- **Seam** — a boundary between modules where they connect. *(not "boundary" loosely)*
- **Adapter** — a piece of code that bridges across a seam.
- **Leverage** — the practical payoff of a deepening: how much future change-cost it removes, ÷ the cost
  of doing it. This is the ranking signal, not lines saved.
- **Locality** — how well the logic needed to understand one behavior sits in one place vs scattered.

## The three tests (how a candidate qualifies)

- **Deletion test** — for any module, ask: if I delete it, does the complexity *disappear* (it was
  carrying real weight — leave it) or merely *relocate/spread* into its callers (it was a shallow
  pass-through — candidate to collapse or deepen)?
- **Two-adapters rule** — one adapter across a seam = a *hypothetical* seam (likely a false abstraction: a
  single-implementation interface earning its keep only in theory). Two real adapters = a *load-bearing*
  seam worth formalizing. A one-implementation interface is a smell until a second forces it.
- **Interface-as-test-surface** — if a module's interface can't be tested without reaching inside it, the
  interface is leaking implementation. An untestable interface is a design defect, not a testing gap.

## Ousterhout's red-flags (the symptom taxonomy to scan for)

Name the specific symptom in each finding — a finding without a named symptom is an opinion:

- **Shallow module** — interface complexity ≈ implementation complexity; it hides little.
- **Information leakage** — the same design decision is baked into two+ modules, so both must change
  together.
- **Temporal decomposition** — modules split by *execution order* (read → process → write) instead of by
  *knowledge*, forcing the same information through every stage.
- **Overexposure / pass-through method** — a method that just forwards to another, adding interface
  without adding function. **Conjoined methods** — two methods you can't understand or change without
  reading the other.
- **Repetition & poor locality** — logic needed together lives apart; a reader bounces across modules to
  follow one behavior.

Grade each against the three measurable costs Ousterhout names: **change amplification** (one change
touches many places), **cognitive load** (how much you must hold in your head to change safely), and
**unknown-unknowns** (you can't tell what you'd need to change). These are the target — not line count.
**Deepening is not DRY or cleanup:** the right deepening (adding an adapter, absorbing a leaky helper into
its one caller) can *add* lines while cutting all three costs. SLOC is never the reward signal here.

## Procedure

### Step 1 — Resolve TARGET, then the classification gate (do this before any analysis)

Resolve from ARGUMENTS what to analyze and where it lives (repo/path). If missing and not obvious from the
conversation, ask which codebase — don't guess. Parse `--report-only` (default **on**; the command is
report-only unless Douglas explicitly asks it to apply a chosen deepening).

Then gate — refuse to burn the analysis on work that is meaningless or already done, and say which case:

- **Too greenfield / too small** — a handful of files with no accreted structure has no depth problem to
  find yet. Say so; suggest coming back once the code has taken shape. Don't manufacture opportunities.
- **Unchanged since last run** — if a prior `declutter` HTML report exists and the hot-spots haven't moved,
  say the architecture hasn't shifted and there's nothing new; don't re-emit the same report.
- **Wrong tool** — if the real problem is breadth-of-debt (`/tech-debt-audit`), speed (`/hone`), a live
  bug (`systematic-debugging`), or UI structure (`/design`), name it and hand off instead of proceeding.

State in one line that the gate passed (and why) before Step 2.

### Step 2 — Explore: hot-spots first, then friction

Target attention where change actually concentrates — cold, stable code with an ugly interface costs
little; the interface you edit weekly costs every week.

1. **Hot-spots from git history** — rank files/dirs by change frequency and by count of distinct authors/
   sessions touching them (`git log --format= --name-only | sort | uniq -c | sort -rn`, plus recency).
   These are where depth problems hurt most.
2. **Walk the hot-spots for friction** — for each, look for: module-bouncing (following one behavior
   across many files), shallow interfaces, information leakage, temporal decomposition, pass-through/
   conjoined methods, poor locality, leaky seams, and untested interfaces. Apply the three tests. Name the
   symptom for each.
3. **Assemble candidate deepening opportunities** — each is: the shallow shape today → the deeper shape
   proposed, the named symptom, which of the three costs it cuts, and a **leverage** estimate (payoff ÷
   cost of the change). Drop anything that fails the deletion test (deleting it wouldn't concentrate
   complexity) or is pure cosmetic cleanup with no depth gain.

### Step 3 — Present: the deepening-opportunities report

Emit a **self-contained single-file HTML report** (inline CSS/JS, no external deps, works opened from
disk) listing the candidates ranked by leverage. Follow `~/.claude/DESIGN.md` and
`~/.claude/DESIGN-dashboards.md` (mono, palette, borders-over-elevation, redundant encoding). Each card:

- **Title + named symptom** (e.g. "Shallow pass-through: `TrussExporter` — overexposure").
- **Before / after shape** — a small concrete diagram or code-shape sketch of the interface today vs
  proposed. Concrete, not "consider refactoring."
- **Problem** — which of change-amplification / cognitive-load / unknown-unknowns it causes, in one line.
- **Benefit / leverage** — what future change-cost the deepening removes.
- **Recommendation-strength badge** — `strong` / `worth-it` / `speculative`, driven by leverage and by
  whether the seam is load-bearing (two-adapters rule) vs hypothetical.
- **Route badge** where the real fix belongs elsewhere — `→ /hone` (perf), `→ systematic-debugging`
  (bug), `→ /design` (UI IA), `→ /tech-debt-audit` (breadth) — so a mis-scoped item leaves cleanly
  instead of getting a bad architecture fix.

Write the report to the target repo (e.g. `<repo>/declutter-report.html` or a `docs/`/reports dir if one
exists) and give Douglas the full absolute path. Then summarize the top 3 in chat.

### Step 4 — Grill / act loop on the chosen candidate (opt-in)

Only for a candidate Douglas picks:

1. **Grill it** — walk the constraints and dependencies of the proposed deepening before touching code:
   what calls the current interface, what the seam actually carries, whether the two-adapters rule holds,
   what tests pin current behavior. Surface anything that would make the deepening unsafe.
2. **Route if it's not really architecture** — if grilling reveals the friction is perf → `/hone`; a live
   bug → `superpowers:systematic-debugging`; a UI restructure → `/design`. Hand off; don't force it.
3. **Apply only if Douglas says apply** (default is `--report-only`, so this needs an explicit go). Do the
   deepening in an **isolated git worktree**, keep the change to exactly what the deepening requires, and
   verify with `superpowers:requesting-code-review` before it lands. For the lazy/leverage lens on whether
   the change earns itself, `ponytail:ponytail-debt` is the complementary read.
4. **Capture the decision** — when a deepening is decided (done or deliberately declined), record it: a
   short entry in the repo's `CONTEXT.md`/`STATUS.md`, or an ADR if the codebase keeps them, so the
   reasoning isn't lost to the next session or the next agent.

## Orchestration map (route, don't duplicate)

| Friction really is… | Hand off to |
|---|---|
| Breadth of debt (dead code, deps, TODOs, dup, weak tests) | `/tech-debt-audit` |
| Slow (runtime / memory) | `/hone` |
| A live correctness bug | `superpowers:systematic-debugging` |
| UI information architecture / UX structure | `/design` (or `/design-review` to assess first) |
| "Does this change earn its keep?" leverage/laziness read | `ponytail:ponytail-debt` |
| Verifying an applied deepening | `superpowers:requesting-code-review` |

## Safety constraints

- **Read-only by default.** `--report-only` is on unless Douglas explicitly asks to apply a chosen
  deepening. Analysis and the HTML report touch nothing but the report file.
- **No elevated / bypass permissions**, ever.
- Any actual deepening (Step 4.3) happens in an **isolated git worktree**, never the caller's main tree;
  clean up with `git branch -d` (two separate calls), never `-D`. No commits unless Douglas asks.
- Only the change the deepening requires — no drive-by refactors, no reformatting unrelated code.

## Final report (honesty register)

Report, in the register of `/hone` and `/spar` — what was verified this pass, not a completeness claim:

- The **hot-spots** examined and the **opportunities surfaced**, ranked by leverage — explicitly "surfaced
  this pass," not "every architecture problem in the codebase." A `declutter` run is a pass over the current
  hot-spots, not a proof the rest is sound.
- Which candidates were **routed elsewhere** and to what.
- The full absolute path of the HTML report.
- For any applied deepening: what changed, in which worktree, and the review verdict.
- Known limitation, stated plainly: this reasons about depth through one lens; it does not measure runtime,
  does not run the target, and does not catch debt outside module/interface design.
