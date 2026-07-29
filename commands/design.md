---
name: design
description: "Senior-product-designer process skill for planning and designing an app or major feature end to end — greenfield, or as a brownfield feature added INTO an existing app (--add mode: extract and conform to the app's patterns, map integration points, gate on no-regression). Runs FRESH per-project recon on how practitioners design this kind of product, then adapts a base design process (problem definition -> concept + parallel variations -> requirements/functionality -> interaction design -> build pathway -> fidelity ramp + testing -> documentation/presentation), integrates Douglas's installed build pathways and skills (skill-pathways.json chains, superpowers construct flow, impeccable, probe/spar/hone tail), and plans model delegation (GEN workhorse per DELEGATE.md). Three independent mode axes: plan (present the design, stop) vs auto (execute the build), collaborate (batch clarifying questions up front) vs delegate (state assumptions and decide), and new (greenfield) vs add (brownfield feature into an existing app, auto-detected). Ends with a product-designer-style design-review artifact of full functionality and status. Use when Douglas says 'design this app', 'plan out this app properly', 'take the position of a senior designer', 'requirements and functionality list for X', 'run the design process on X', '/design'."
---

# /design [brief] [--plan|--auto] [--collaborate|--delegate] [--new|--add]

An app designed by accretion of features reads like one; an app designed from a problem statement reads
like a product. This command is the difference, encoded. It does not start from "what should I build" —
it starts from who the user is, what job they are hiring the app for, and what measurably counts as
success, and only then lets concepts, requirements, and pixels exist. Every phase produces a small,
honest artifact that feeds the next, and the whole run ends the way a real product designer ends a cycle:
presenting the work — problem, explorations, decisions, status — to someone who wasn't in the room.

Three hard-won rules govern every run (from the 2026-07-11 research pass that built this skill; rule 3 added 2026-07-17):

1. **No process theater.** The Double Diamond's own originators concede most uses of it are performance
   (Design Council retrospective); Erika Hall calls packaged sprints "snake oil." A phase that produces an
   artifact nobody downstream reads gets cut, per project, explicitly. Right-size everything: the brief is
   1-2 pages of WHY; the spec covers only what is being built now.
2. **A test validates only what it measures.** A usability pass proves usable, not valuable. State what
   each evaluation in the fidelity ramp actually demonstrates — never launder "it renders and clicks" into
   "the design works."

3. **Deviate out loud.** This staged process is the well-reasoned default. When you genuinely judge that a
   specific situation calls for a different move than the skill prescribes, surface the divergence and your
   reasoning to Douglas and let him decide, instead of silently complying or silently going your own way.

The staged process, the game-dev production disciplines (Steps 6 and 8), and the collaborative-review
methodology (Step 9) are folded in from the practitioner synthesis
`NASA_GSFC_Vault_1/Claude/Learn/Frontend Design Process & Collaborative Review.md` (18 sources, 2026-07-14).

## What this is NOT

- **Not `/recon`.** `/recon` maps a landscape to help Douglas DECIDE (adopt/improve a tool or approach).
  `/design` presumes the decision to build is made and owns the design arc for the thing being built. Its
  Step 1 recon is scoped to the product domain of THIS project, not a general landscape survey.
- **Not `superpowers:brainstorming`.** Brainstorming explores intent and requirements conversationally
  before creative work — it is one INGREDIENT here (the collaborate-mode questioning discipline), not the
  whole. `/design` wraps it in problem definition, parallel concepts, a build pathway, delegation, and a
  presentation plan. When `/design` runs, do not also run brainstorming separately — Step 3 subsumes it.
- **Not `superpowers:writing-plans`.** writing-plans turns an already-decided spec into implementation
  steps. `/design` produces the spec (and then hands off to writing-plans inside its build pathway).
- **Not `/spec`.** `/spec` produces the WHAT artifact (the tech-agnostic `SPEC.md` — PRD + functional +
  acceptance oracle). `/design` is the whole design arc and CALLS `/spec` at Steps 3 and 5 rather than
  re-deriving it. Want just the spec, not the full arc? Run `/spec` standalone.
- **Not `impeccable`.** impeccable designs and polishes INTERFACES — visual hierarchy, motion, theming.
  `/design` decides what the product IS, then routes UI work through impeccable as a pathway step.
- **Not `/pathway`.** `/pathway` executes an existing named chain of skills. `/design` COMPOSES a
  per-project chain (which may then be run via `/pathway` or directly).
- **Not `/ultraskill`.** That builds new SKILLS. This designs and (in auto mode) builds APPS/features.

## Modes (three independent axes; default --auto --delegate --new unless Douglas says otherwise)

- **--plan**: run Steps 0-8, write the design package, PRESENT it, stop before building anything.
- **--auto**: same, then execute the build pathway to completion.
- **--collaborate**: batch ALL clarifying/scope-honing questions into ONE AskUserQuestion at the start
  (after Step 1 recon has sharpened them) — never ping-pong mid-run. Mark Claude's RECOMMENDED option first
  in each question (Douglas's standing AskUserQuestion preference). Never ASK a fact you can DISCOVER — look
  it up in the recon or the repo; reserve questions for genuine judgment calls (Matt Pocock's grill-me rule).
- **--delegate**: ask nothing; convert every ambiguity into a stated assumption in the design brief, each
  marked `ASSUMED:` so Douglas can veto later. Ambiguities that would waste >10 min if guessed wrong still
  get surfaced (his standing autonomy rule outranks this mode).
- **--new**: greenfield — the full from-scratch arc below (parallel concepts, problem-first).
- **--add**: brownfield — a feature added INTO an existing app; Step 0 auto-detects this when the target names
  an existing codebase plus a feature, and an explicit `--add` is honored. In this mode the **Brownfield mode**
  section (after Step 11) replaces the greenfield concept/spec/test steps with extract-and-conform, a fit map,
  and a regression-safety gate. The `--new`/`--add` axis composes with the plan/auto and collaborate/delegate axes.

The spec-kit `[NEEDS CLARIFICATION: <gap>]` marker is used in both modes: collaborate resolves them by
asking; delegate resolves them by assumption and leaves the marker's resolution visible in the artifact.

## Procedure

### Step 0 — Resolve the brief and modes

Needs: what the product/feature is, who it's for, what exists already (path to any prior art in the repo),
and the mode flags (across all three axes). If the ask names an existing codebase, READ its current state first (STATUS.md,
LOG.md, the app itself) — designing over an inaccurate picture of what exists is the first theater trap. When the ask ADDS a feature to
an app that already exists, set `--add` and follow the Brownfield mode section — the greenfield concept arc is
the wrong shape for fitting into an existing app.

### Step 1 — Fresh recon, per project (never skipped, never generic)

Research how practitioners design THIS KIND of product — the domain, not design-process-in-general (that's
baked in below). For a schema editor: how do Protégé/Sanity/Contentful structure schema editing? For a
provenance viewer: how do annotation tools draw text-anchored links? 3-6 bounded searches; read the 2-3
strongest sources' actual substance. Output: a short "prior art" section — patterns to adopt, patterns to
avoid, each with source. If subagent fan-out is available and safe, delegate this; otherwise run it inline
and keep it bounded.

### Step 2 — The gate (mandatory, before any artifact-writing)

Stop conditions, checked honestly:
1. **Too small for the process?** A single-screen tweak or a one-line change doesn't need problem
   definition + concepts — route straight to the right implementation skill (impeccable for UI, TDD for
   logic) and say so. A genuine FEATURE added to an existing app is bigger than that: run **Brownfield mode
   (--add)** below, ahead of the greenfield concept arc. The full from-scratch arc is for new apps / major surfaces.
2. **Already designed?** If a current design doc/spec already answers Steps 3-5, don't re-derive it —
   validate it against the recon and move to the pathway.
3. **Not actually a design problem?** "Make it faster" is `/hone`; "it's broken" is systematic-debugging.
   Reviewing an EXISTING app's design (not building new) is `/design-review`, not this.

**Escalate to `wayfinder`** when the brief is large, multi-session, or decision-heavy: route the open
decisions to wayfinder as decision tickets instead of burying them mid-run (mirrors the `/task`↔wayfinder
link). The design still runs here; wayfinder just holds the decision state so nothing gets lost across sessions.

### Step 3 — Problem definition (the design brief, 1-2 pages MAX)

**Delegate the artifact to `/spec --prd-only`.** The §Product layer of a spec IS this problem-definition (root
problem, users, JTBD, measurable outcome metrics, non-goals) — `/spec --prd-only` writes it to `SPEC.md` as the
single definition, so this step and `/spec` never drift. Run it here; the checklist below is what `/spec`
produces, kept inline as the review rubric for what it returns. Step 5 later completes the same `SPEC.md`.

The WHY document, in Douglas's register (no antithesis constructions):
- **Find the root problem beneath the request**: a request for feature X usually names a symptom; find the
  problem Y underneath it, because shipping X can pass while leaving Y untouched. Judge the framing by
  whether every reasonable angle was weighed — a decision made from missing context is the real failure
  (*The Linear Method* / *Build a Trustworthy Design Process*).
- **User & context**: who uses this, expertise level, environment. For Douglas's tools the honest persona
  is usually "Douglas, expert, impatient, evaluating his own data" — write it anyway; it forces decisions
  (expert-facing = density over hand-holding, keyboard-first, no onboarding tours).
- **Jobs to be done**: the 3-6 jobs the user hires the app for, as verbs, ranked.
- **Success criteria**: measurable, technology-agnostic (spec-kit SC pattern): "can go from schema edit to
  seeing new extraction output in under N seconds", not "has a good UX".
- **Appetite**: the fixed time/effort budget this is worth — an afternoon, a day, a week — stated before
  any solution exists, with scope as the variable that flexes to fit it (Shape Up's fixed-time/variable-scope
  bet). Anything that would blow the appetite moves to Non-goals.
- **Constraints & assumptions**: platform, data, offline/online, and every `ASSUMED:` from delegate mode.
- **Non-goals**: what this deliberately will not do — the cheapest scope control that exists.

### Step 4 — Concept design, in parallel (Dow et al.: parallel beats serial)

**In `--add` mode, skip this step** — competing from-scratch concepts fight the existing app's established
mental model; use Brownfield mode's B2 (conform to the extracted patterns) instead.

Generate 2-3 genuinely different concepts (different IA/layout/mental model — a different accent color is
one concept, cheating). For each: a one-paragraph conceptual model (Norman: what the user believes the
system is), the primary screen's layout in words or ASCII, and the walk of the #1 job through it. Pick one
with stated criteria (QOC-style: the question, the options, the criteria that decided it) and graft the
runners-up's best ideas. Record the decision — this paragraph IS the decision log entry. Treat the weak
concepts as earning their place: exploring a blind alley is what clarifies why the winner is better
(*The Linear Method*).

### Step 5 — Requirements & functionality (the spec — only what's being built now)

**Delegate to `/spec`** (completing the same `SPEC.md` that Step 3's `/spec --prd-only` began). `/spec` owns
the §Functional (prioritized independently-testable stories + FR-### + entities) and §Acceptance (the
machine-readable ground-truth oracle) layers, technology-agnostic — do not re-derive them inline here, or the
two definitions drift. The skeleton below is what `/spec` produces, kept as the review rubric for its output.
The technical HOW stays out of `SPEC.md` and lands in Step 7's `writing-plans`.

In `--add` mode, the spec also carries the **fit / integration map** (Brownfield B3): every existing file,
flow, and component the feature touches, and what it must leave working.

Spec-kit's proven skeleton, right-sized:
- **Prioritized user stories** P1/P2/P3..., each INDEPENDENTLY TESTABLE — P1 alone must be a usable app
  (this is the MVP slice and the build order).
- **Functional requirements** FR-001... — testable statements, no tech-stack language.
- **Non-functional requirements** that will actually be checked (perf budgets, offline behavior, data
  scale) — skip boilerplate NFRs nobody will measure.
- **Key entities** and their relationships (for data apps this is the load-bearing section).
- Every ambiguity: `[NEEDS CLARIFICATION]` → resolved per mode.

### Step 6 — Interaction design & design language

- **IA**: screens/panels, navigation model, where each job lives. Expert-tool defaults: command palette,
  keyboard shortcuts, dense tables, inline editing, persistent state.
- **Key flows**: the P1 stories as concrete step-by-step interactions (Given/When/Then reads well here).
- **AI-native interaction — when the product surfaces model/LLM output** (skip entirely for a purely
  deterministic surface, per rule 1). A surface showing probabilistic output needs interaction patterns a
  deterministic tool never does, and most of Douglas's apps are this shape (extraction viewers, CAD/gate
  outputs, anything reading a model's judgment). Design four things explicitly (Google PAIR *People + AI
  Guidebook v2*; the Shape of AI pattern catalog):
  - **Position the model as an assistant the user oversees and can override at every step** (PAIR *Feedback +
    Control*; Shape of AI *Governors*): render generated output into an editable field or card the user can
    correct before it commits, and gate any action that writes to a system of record behind an explicit confirm.
  - **Calibrate the user's trust deliberately** (PAIR *Explainability + Trust*): where a wrong answer is costly,
    show confidence/provenance (N-best, a numeric level, or the source it drew from) and keep the model's
    limits legible, so the user knows when to apply their own judgment. Honest uncertainty up front trades a
    little immediate trust for durable reliance.
  - **Stream long generations token-by-token with a stop control**, and design the mid-stream failure — a
    dropped connection swaps to an error state that preserves the user's work and offers retry, with no
    truncated sentence left hanging. (Streaming cuts perceived wait well past half at identical total latency.)
  - **Decide automate-vs-augment per feature** (PAIR): automate the difficult / unpleasant / high-scale task
    with an agreed-correct method; augment the task the user enjoys or where "correct" is contested — and give
    users more control where failure tolerance is low.
- **Component architecture**: think atoms → molecules → organisms → templates → pages, so the UI reads as
  whole and parts at once. Build single-responsibility components and compose them, so flexibility comes
  from combination rather than a bespoke state per scenario. Define templates around content structure
  (image sizes, character-length ranges) so a pattern holds when a heading runs 340 characters (*Atomic
  Design*). Reach for accessibility-focused headless primitives (Radix under shadcn/ui) for the hard widgets
  — modals, dropdowns, comboboxes — per `~/.claude/DESIGN.md`'s library picks.
- **Design language**: named reference (e.g. "Cursor's language: quiet chrome, layered surfaces, restrained
  motion"), base palette as tokens, type system, spacing scale. Route the visual build through `impeccable`
  using its RIGHT command per need — `shape` (plan UX/UI before code), `layout` (spacing/rhythm/hierarchy),
  `typeset` (type), `colorize` (strategic color), `brand`/`delight` (identity/personality), `onboard`
  (first-run/empty states), `animate` (motion), `extract` (pull tokens/components into a design system) — not
  one generic "make it pretty" pass. Read `~/.claude/DESIGN.md` (house rules layered on impeccable; also
  `~/.claude/DESIGN-dashboards.md` for a dashboard/data-dense surface) and check output against it.
  - **Taste BEFORE code = impeccable owns it.** The "read the room, set the direction" thinking is `impeccable
    shape` (discovery-interview design brief) + the register reference it loads (`reference/brand.md` for
    landing/marketing/portfolio, `reference/product.md` for app/dashboard/tool). Do NOT re-derive a separate
    "design read" from a Leonxlnx taste-skill at build time — shape+brand already do it, deeper, and read
    PRODUCT.md/DESIGN.md. When the Design Read (Step 2–3) lands on a strong aesthetic LANE, additionally read
    the matching Leonxlnx reference for its concrete moves: Awwwards/agency/expensive → `high-end-visual-design`;
    editorial/minimal/monochrome → `minimalist-ui`. Existing UI to upgrade → `redesign-existing-projects`.
  - Respect the standing anti-patterns (`feedback_frontend_ai_isms`, `feedback_design_incidents` — separate
    regions with elevation/tone + whitespace, not boxes; no UI commentary text, a11y deprioritized except contrast).
- **Evaluation gates (the taste + technical pass)** — all at REVIEW time, on what got built:
  1. `impeccable critique <surface>` — heuristic-scored UX review (Nielsen 0–4, cognitive load, AI-slop verdict)
     + its bundled `detect.mjs` slop scanner (side-stripe borders, gradient text, eyebrow-every-section,
     numbered markers, hero-metric template, identical card grids, overflow). `/design-review` is this review
     for an already-built app.
  2. `~/.claude/DESIGN.md` house-rule check. Where any taste-skill and `DESIGN.md` conflict, **DESIGN.md wins.**
  3. **For landing/portfolio surfaces only**, also run the `design-taste-frontend` §14 pre-flight matrix as a
     supplementary lint — it is FAR more granular than impeccable's slop bans (zero em-dashes, hero stack ≤4
     elements + fits viewport, CTA-wrap ban, duplicate-CTA-intent ban, banned premium-consumer beige+brass hex
     families, serif discipline, logo-wall-under-hero, bento exact-cell-count, marquee-max-one). This §14 lint
     is the taste suite's one genuinely non-duplicated asset; the rest overlaps impeccable. It does NOT apply to
     dashboards/tables/product UI (the skill excludes them — most of Douglas's work).
  4. `impeccable audit` for a11y/perf/responsive.

  Back these with Nielsen's heuristics (visibility of status, user control/undo, error prevention, recognition
  over recall) at each fidelity step.

### Step 7 — Build pathway & model delegation (the plan for HOW)

Compose the per-project chain from what is actually installed (check `~/.claude/hooks/skill-pathways.json`
and the live skill list; never hardcode a stale roster). If this project reveals a pathway GAP — a recurring
shape no existing chain covers, or an installed chain needing a step added/removed — DECIDE whether to author
a new pathway or edit an existing one, and delegate that to `/trailblaze` (never hand-edit
`skill-pathways.json` inline from a design run). Typical shape:
`writing-plans -> TDD (logic) + impeccable (UI) per story -> verify (Playwright) -> harden-tail chain
(solo-review -> probe -> hone -> spar) on the finished P1+P2`.
Then the delegation plan per `DELEGATE.md`: which phases run on GEN (bulk generation, NASA + no-web —
usually most of the build), which stay in the main session (judgment, verification, web research), and the
subagent model tiers. BMAD's planning/implementation split is the model: plan where judgment is cheap to
apply, generate where tokens are cheap.

**De-risk before betting the build (Shape Up ch. 5, Risks and Rabbit Holes).** Before the pathway runs, name
every rabbit hole — a technical unknown, an unsolved design problem, a misunderstood interdependency between
stories — and for each either patch it (decide the tricky detail now), fence it (declare it out of bounds,
into Non-goals), or spike it (a timeboxed proof before the real build). Well-shaped work carries a thin-tailed
risk distribution; an unpatched rabbit hole is how a one-day feature swells past the appetite. List the rabbit
holes and their patches in the design package.

### Step 8 — Fidelity ramp & testing plan

In `--add` mode, the testing plan MUST include the **regression-safety gate** (Brownfield B4): a captured
baseline of current behavior before the change, test-suite health as a precondition, and a regression check after.

Lo-fi first, and honestly: structure/layout with real data before polish (lo-fi finds the same issues
hi-fi does — Walker et al.; and real data beats lorem ipsum for expert tools, always). Ramp:
skeleton with real data -> P1 flows working -> `impeccable critique` (heuristic taste gate) -> polish
(`impeccable polish`; `bolder`/`quieter`/`distill` to tune intensity, `delight` for personality, `onboard`
for empty/first-run states, `harden` for edge cases, `animate` for motion) -> `impeccable audit` (a11y/perf)
-> Playwright end-state verification of every interaction -> adversarial pass. Name what each stage validates
and what it cannot.

**The production disciplines** (borrowed from game development — *Blockout*, *Iterative Level Design*,
*The Vertical Slice*, *Game Feel*, *Juice It or Lose It*):

- **Greybox before art.** Validate layout and flow in grayscale before color, type, or finished components
  exist — a blockout stays cheap to change while finished assets are expensive to replace. Beat blank-page
  paralysis by placing one rough screen to start the loop. *Exception:* when the value lives in
  brand/emotion/feel rather than layout, go straight to hi-fi or reference research — a grayscale wireframe
  can't test whether the feel lands. For Douglas's data/CAD surfaces layout usually IS the value, so greybox
  applies most of the time.
- **Vertical slice as the quality bar.** Take ONE screen/flow all the way to production fidelity first, with
  real representative content and modeled edge cases (empty vs full, first-run vs returning). That finished
  screen becomes the concrete bar the rest must meet; the others stay greybox until built to it. Taking
  every screen to ~60% teaches nothing about what "done" costs.
- **Content-complete before polish.** Get the whole flow functionally end-to-end with no broken or missing
  states before any polish pass. A complete rough build proves the runway; polish is the second lap.
- **Breadth-first passes.** Advance every screen to the same fidelity per pass — all to wireframe, then all
  to interaction, then all to visual — so patterns stay consistent and a review always sees the whole
  product at one level. Stage the reviews by concern: IA → interaction → visual → polish, and hold styling
  until layout is signed off. (Weigh this against the solo-builder "finish one flow" instinct, which pulls
  the other way — a genuine open question from the source note, worth testing per project.)
- **Nail the core repeated interaction early.** For Douglas that's typing, scrolling, table/grid navigation,
  CAD-viewport manipulation — the action the user spends most of their time on is the foundation of
  perceived quality, so tune its feel from the first pass (*Game Feel*).
- **Juice as a dedicated pass.** Layer hover states, easing, and subtle motion onto working interactions;
  tween state changes so motion communicates cause and continuity instead of teleporting. Reserve heavy
  motion for genuinely significant moments so users don't go numb to it. Calibrate to how serious the tool
  is meant to feel — a NASA/engineering surface may want motion while leaving out sound and mascots. (No
  bounce/elastic easing; respect `prefers-reduced-motion` — per `~/.claude/DESIGN.md`.)
- **Cut what isn't clicking by the confidence pass.** Elevate the flows with real upside and drop the rest —
  raising a good thing to great beats dragging a weak thing to mediocre.
- **Leave missing states visible.** A hacky CSS patch that hides a gap gets the gap forgotten; leave it
  visible so it gets scheduled and solved (*Iterative Level Design*).
- **Treat finishing as its own discipline.** Push the current version to done; resist rebuilding the design
  system mid-project (*How Spelunky Got Its Procedural Hook*).

### Step 9 — Documentation & presentation (the design review, planned up front)

Plan it in Step 3, produce it at the end — a product designer presenting to teammates/superiors:
- **The design-review artifact**: problem -> what was explored (concepts, with the rejected ones and why)
  -> what was decided (QOC decisions) -> what was built (functionality tour, per story, with status
  shipped/partial/not-started) -> evidence (verification results, honestly scoped) -> what's next.
- **Explainers via `/onboard`** (distinct from impeccable's `onboard` empty-state command above — this is the
  slash command `/onboard`): once the app is built, add two comprehension surfaces. Run `/onboard --user` to add
  the in-app help — a question-mark icon top-right that opens an overlay explaining to the END USER what the app
  does and how to use it, conforming to the design language from Step 6. For a build Douglas will maintain, also
  offer `/onboard --dev` to generate the standalone developer explainer (system map + data flow + one traced
  feature). Both teach terms rather than hiding them (name-then-plain-gloss).
- Substantial version goes to the Obsidian vault (per the Briefs->Obsidian rule) or the project folder as
  an HTML/md design-review doc; chat gets the summary. Full paths in the Files list, always.
- **Run the review against a structured record** (the collaborative-review methodology) so it evaluates
  against stated goals rather than drifting into taste. Before critique opens, the record states: the root problem, the goals (user/business vs solution
  standard), the completion stage (30/60/90%), and the feedback wanted plus the feedback NOT wanted — this
  keeps a mushy early concept from drawing polish notes and near-final work from drawing directional churn.
  Reveal the problem and research before the artifact, so critique evaluates against the user problem
  instead of reacting to aesthetics. Present the artifact as a journey (a sequence with transitions), and
  tag each visual choice to a research/goal/constraint rationale.
- **Structured-feedback formats.** Collect silent, justified notes first (before anyone sees others') in an
  "I Like / I Wish / What If" frame; affinity-cluster them, label the themes, and prioritize by severity
  (Blocker/Major/Minor/Cosmetic) or Impact/Effort. Respond to the patterns that repeat; for any prescribed
  fix, extract the underlying pain and re-solve it rather than applying the patch. Aim every critique at the
  design itself and use "the design" language, so feedback never lands as a personal judgment.
- **Solo-builder adaptation.** Working alone, Claude plays the reviewer roles against the same record: a
  **pre-critique pass** for surface defects (contrast, spacing, missing states, inconsistent tokens) so
  attention goes to structure; a **synthetic-stakeholder pass** generating persona-driven feedback (a
  first-time CAD user, an admin) and listing unanswered questions to counter the HiPPO effect; and periodic
  **meta-critique** across past review records to surface recurring unresolved patterns. Most of the
  discipline lives in writing the record honestly. `/design-review` is the standalone version of this review
  for an already-built app; the full methodology and the reviewer-app feature list live in the source note.
- **Retire the planning artifacts on ship.** Once the build lands, mark the brief + spec as superseded — a
  dated `STATUS: implemented — see <review doc>` header, or move them to an `_archive/` — so a later
  session/agent never treats a stale spec as authoritative and rebuilds against an outdated plan (Matt
  Pocock's doc-rot discipline; the review artifact, which reports real shipped state, becomes the live doc).

### Step 10 — Execute (auto) or present (plan)

**Pre-build consistency gate (spec-kit's `/speckit.analyze` pattern), first in either mode.** One READ-ONLY
pass across the artifacts as a set — brief, spec, pathway: every FR/story maps to a pathway step (and every
pathway step back to a story), no requirement stated twice in conflicting ways, no unresolved
`[NEEDS CLARIFICATION]`, no collision with `DESIGN.md` house rules. Fix the artifacts before proceeding — a
gap caught here costs an edit; the same gap caught mid-build costs a rebuild.

- **--plan**: assemble Steps 3-9 into the design package, present, stop.
- **--auto**: drive the pathway from Step 7, story by story in priority order, updating WORK_QUEUE per
  item, verifying per Step 8, and closing with the Step 9 review artifact.

### Step 11 — The honest final report

**Convergence sweep first (spec-kit's `/speckit.converge` pattern).** Diff the spec against what shipped:
every story and FR gets an explicit status — shipped / partial / blocked / cut (a cut is recorded as a
decision, with its why). In `--auto`, actionable gaps go back into WORK_QUEUE and the build loops until the
diff converges or a gap is explicitly parked; the report then states the final diff, so nothing in the spec
can silently vanish between plan and ship.

In the register of `/spar`/`/hone`/`/probe`: what was designed, what was built and VERIFIED this pass
(with the verification evidence), what remains, which assumptions still need Douglas's veto, and the full
Files list. Banned: "fully designed", "production-ready", "complete UX" — a design review reports state,
never certifies perfection.

## Brownfield mode (--add) — design a feature INTO an existing app

Adding a feature to an app that already exists is a different job from greenfield: the app already has an IA,
conventions, a component architecture, and a design language, and the feature's job is to CONFORM and slot in
while leaving what works intact. When Step 0 set `--add`, these sub-steps replace the greenfield Steps 1, 4,
5, and 8; Steps 3 (root problem), 6 (interaction, held to the existing design language), 7 (build pathway),
and 9-11 (review/report) still apply. Built from the 2026-07-17 research pass (BMAD-METHOD's brownfield
workflow, Michael Feathers' *Working Effectively with Legacy Code*, Martin Fowler's strangler-fig and
branch-by-abstraction).

**B1 — Extract and map the existing app first (replaces the from-scratch half of Step 1).** Before designing
anything, generate a map of what exists: the architecture, the IA, the naming and code conventions, and an
inventory of the components, tokens, and utilities already in the app (BMAD's document-project; Matt Pocock's
CONTEXT.md of project vocabulary, so names stay consistent with the system). Read the real code and the real
running app. Output a short 'existing patterns' section that the rest of the mode conforms to.

**B2 — Conform to the existing patterns (replaces Step 4's parallel concepts).** Design the feature to fit the
extracted patterns instead of generating competing mental models. Three disciplines carry it:
- **Reuse before you add** — an existing component, token, or utility that fits gets reused; a new one is
  justified only when nothing existing serves (design-system reuse discipline).
- **Additive over in-place** — add the feature as new code called from the old (Feathers' Sprout
  method/class), and reserve editing shared logic in place for a change that must intercept every call
  (Wrap method).
- **Chesterton's fence** — before changing or removing existing code, establish WHY it is the way it is
  (commit history, docs, original intent); a change made without that context is the real risk.

**B3 — Fit / integration map (augments the Step 5 spec).** Name every existing file, flow, and component the
feature touches, and state explicitly what it must leave working. Where the change cannot land atomically,
pick a coexistence mechanism so the app stays releasable throughout — branch by abstraction, a strangler-fig
shift, or a feature flag (Fowler) — over a big-bang edit.

**B4 — Regression-safety gate (augments Step 8, mandatory before done).** In order:
- **Precondition — test-suite health.** Check whether the existing suite actually exercises the code being
  touched. A codebase with no or broken coverage there needs **characterization tests** (pinning the behavior
  the code exhibits today) written FIRST, or the after-check proves nothing (Feathers).
- **Baseline before the change** — capture current behavior (the characterization/golden-master output) so
  there is something to diff against.
- **Regression check after** — re-run that baseline plus the existing suite and confirm the only behavior that
  changed is the feature. New tests for the new feature stand alongside this check, never in place of it.
- **Rollback path** — name how the feature is turned off cheaply if it breaks something in use anyway (the
  feature flag or abstraction from B3), separate from the pre-ship check.

**Flagged-open (check, and state honestly if unresolved).** Two concerns the research could not fully source,
so surface them plainly: whether the feature bumps or constrains a **shared dependency** the rest of the app
relies on, and whether it **supersedes an old code path** that should then be deprecated and removed once the
change lands (the tail of a strangler-fig migration).

## Safety constraints

- Never run with elevated/bypass permissions; a blocked call means narrow scope, never route around.
- New-app builds write NEW files in the project folder; edits to an existing app follow the standing
  file-safety rules (backups, never in-place overwrite of authored docs).
- **In `--add` (brownfield) mode, the feature is not done until the B4 regression check passes** against a
  baseline captured BEFORE the change; a feature that ships by breaking an existing flow counts as a
  regression and stays unfinished.
- No commits/pushes unless Douglas separately asks.
- Research is open-web ONLY for public/personal topics — NASA/CUI content never leaves the machine
  (block-nasa-web-egress enforces; don't test it).
- Surgical scope: build what the spec's stories say, nothing speculative (ponytail discipline applies —
  the ladder runs inside every implementation step).

## Workflow script (optional executor for auto mode when fan-out is safe)

When parallel agents are safe to run (no active SentinelOne kill pattern), auto mode MAY drive Steps 4
and 10 through this Workflow; otherwise run the phases inline/sequentially — the process is identical.

```js
export const meta = {
  name: 'design-run',
  description: 'Design process executor: recon -> parallel concepts -> spec -> per-story build -> review artifact',
  phases: [
    { title: 'Recon' },
    { title: 'Extract' },
    { title: 'Concepts' },
    { title: 'Spec' },
    { title: 'Build' },
    { title: 'Regression' },
    { title: 'Review' },
  ],
}

const BRIEF = args.brief            // resolved Step-0 brief, incl. paths + constraints + design language
const MODE = (args.mode || 'new')   // 'new' (greenfield) | 'add' (brownfield feature into an existing app)
const STORIES = args.stories || null // if Steps 3-5 already ran inline, pass the spec; else null builds it here
const MODEL_PLAN = args.modelPlan || 'sonnet workhorse; opus only for concept-pick and final synthesis'

const EXTRACT_SCHEMA = {
  type: 'object',
  properties: {
    architecture_ia: { type: 'string' },
    conventions: { type: 'string' },
    reusable_inventory: { type: 'string' },   // components/tokens/utilities to reuse before adding new
    conform_guidance: { type: 'string' },     // how the feature should fit the existing app
  },
  required: ['architecture_ia', 'conventions', 'reusable_inventory', 'conform_guidance'],
}

const CONCEPT_SCHEMA = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    conceptual_model: { type: 'string' },
    primary_layout: { type: 'string' },
    top_job_walkthrough: { type: 'string' },
    weaknesses: { type: 'string' },
  },
  required: ['name', 'conceptual_model', 'primary_layout', 'top_job_walkthrough', 'weaknesses'],
}

const PICK_SCHEMA = {
  type: 'object',
  properties: {
    winner: { type: 'string' },
    criteria: { type: 'string' },          // QOC: the question, options, criteria that decided it
    grafts: { type: 'string' },            // best ideas taken from the runners-up
  },
  required: ['winner', 'criteria', 'grafts'],
}

const STORY_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    story: { type: 'string' },
    status: { type: 'string', enum: ['shipped', 'partial', 'blocked'] },
    files_touched: { type: 'array', items: { type: 'string' } },
    verification: { type: 'string' },      // what was actually run and observed, not "works"
    remaining: { type: 'string' },
  },
  required: ['story', 'status', 'files_touched', 'verification'],
}

let spec = STORIES
if (!spec && MODE === 'add') {
  log('Brownfield (--add): extracting existing patterns, then a conforming spec + integration map')
  const existing = await agent(
    `Extract the EXISTING app's patterns for a brownfield feature. BRIEF: ${BRIEF}. Read the real code and the ` +
    `running app. Report: architecture + IA, naming/code conventions, an inventory of reusable ` +
    `components/tokens/utilities, and how a new feature should CONFORM. Do not invent competing concepts.`,
    { phase: 'Extract', schema: EXTRACT_SCHEMA, label: 'extract-existing', model: 'opus' })
  spec = await agent(
    `Write the right-sized spec so the feature CONFORMS to the existing app, PLUS a fit/integration map (every ` +
    `existing file/flow/component it touches and what it must leave working) and a regression-safety plan ` +
    `(characterization baseline before, regression check after, a rollback path). BRIEF: ${BRIEF}. ` +
    `EXISTING PATTERNS: ${JSON.stringify(existing)}. Return structured text.`,
    { phase: 'Spec', label: 'brownfield-spec', model: 'opus' })
}
if (!spec) {
  log('Spec was not supplied inline; deriving concepts and spec')
  const concepts = await parallel([1, 2, 3].map(i => () =>
    agent(`Concept ${i} of 3 for: ${BRIEF}. Produce a GENUINELY different IA/layout/mental model from what ` +
      `a default build would do (vary the conceptual model, not the palette). Report per schema.`,
      { phase: 'Concepts', schema: CONCEPT_SCHEMA, label: `concept-${i}` })
  ))
  const pick = await agent(
    `Pick the winning concept via explicit QOC criteria and graft the runners-up's best ideas. BRIEF: ${BRIEF}\n` +
    `CONCEPTS: ${JSON.stringify(concepts.filter(Boolean))}`,
    { phase: 'Spec', schema: PICK_SCHEMA, label: 'concept-pick', model: 'opus' })
  spec = await agent(
    `Write the right-sized spec (prioritized independently-testable stories P1..Pn, FR-xxx, key entities, ` +
    `NFRs that will actually be measured) for BRIEF: ${BRIEF} using winning concept: ${JSON.stringify(pick)}. ` +
    `Return the spec as structured text.`,
    { phase: 'Spec', label: 'spec-write' })
}

log('Building story by story, priority order')
const stories = Array.isArray(spec) ? spec : (args.storyList || [])
const results = []
for (const s of stories) {   // sequential: stories share files; parallelize only proven-disjoint stories
  results.push(await agent(
    `Implement ONE story to done, with verification evidence (run the app/tests, report observed output). ` +
    `BRIEF: ${BRIEF}\nSTORY: ${JSON.stringify(s)}\nPrior results: ${JSON.stringify(results.map(r => r && r.story))}` +
    `\nDiscipline: ponytail ladder, surgical scope, real data, no UI commentary text.`,
    { phase: 'Build', schema: STORY_RESULT_SCHEMA, label: `story-${results.length + 1}` }))
}

if (MODE === 'add') {
  results.push(await agent(
    `Brownfield REGRESSION CHECK: re-run the existing test suite plus the captured behavior baseline and ` +
    `confirm the ONLY changed behavior is the new feature; report pass/fail with the evidence observed. ` +
    `BRIEF: ${BRIEF}. Built: ${JSON.stringify(results.filter(Boolean).map(r => r && r.story))}`,
    { phase: 'Regression', schema: STORY_RESULT_SCHEMA, label: 'regression-check', model: 'opus' }))
}

const review = await agent(
  `Write the design-review artifact (problem -> explorations -> decisions -> functionality tour w/ status ` +
  `-> verification evidence -> next). Honest register: no "fully", no "production-ready". ` +
  `BRIEF: ${BRIEF}\nRESULTS: ${JSON.stringify(results.filter(Boolean))}`,
  { phase: 'Review', label: 'design-review', model: 'opus' })

return { spec, results, review }
```

---

*Tracked copy: also save this file to `claude-global-config/commands/design.md` (per the skills-are-tracked
convention) after a NASA scrub.*
