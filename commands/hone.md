---
name: hone
description: "Measure-driven performance loop for any codebase (Python CAD/solver, JS/HTML frontend, kernel-bound builds). Classify the bottleneck by type FIRST, run an already-optimized/wrong-tool gate BEFORE profiling, then a profile -> propose-one-change -> validate-plan -> apply-in-an-isolated-worktree -> re-measure-vs-baseline -> keep-or-discard-on-the-number -> log loop, and adversarially re-verify any 'it's faster' claim (rerun for noise + run the target's own tests) before reporting it as a keep. By default, any candidate that survives verification is then APPLIED directly to the real target's main tree (re-tested there) — pass --read-only to restore the original diff-handback-only behavior. Carries CAD/3D-specific kernel levers (boolean-op ordering/tree-balancing, tessellation/deflection-tolerance tuning, parametric-rebuild caching, DOF/constraint-solver convergence, batched point-in-solid queries, STEP round-trip batching). Runs in --mode auto (default: full loop to completion, no pause) or --mode plan (Opus profiles + proposes ranked candidates as a written plan and STOPS — no worktree, no trial — resumable with the printed --resume runId). Defers frontend/render work to impeccable's /optimize. Use when Douglas says 'hone', 'hone this', 'make it faster', 'optimize this codebase', 'profile and speed it up', 'where's the bottleneck', 'plan a hone', '/hone'."
---

# /hone [target] [--mode plan|auto] [--max-iterations N] [--budget "<time/mem goal>"] [--resume <runId>] [--read-only]

Performance is a measured claim, never a felt one. This command does not guess where the time goes,
does not trust that a change helped because it "should," and does not report a speedup it saw once. It
classifies the bottleneck, checks whether the work is already done, measures a real baseline, changes
exactly one thing at a time in an isolated worktree, re-measures against that baseline, and keeps or
discards each change purely on the number — then re-checks any keep for noise and breakage before it
counts.

## Mode (read this first)

**Default: APPLY.** When `--mode auto` runs the full measurement loop and a candidate survives Trial AND
the Step-4 adversarial Verify (a genuine keep), hone applies that SAME verified diff directly to the real
target's main working tree — never a worktree at this point, the caller's actual checkout — re-runs the
target's own full test/self-test suite there to reconfirm nothing broke, and reports the outcome. Nothing
is left as a diff Douglas has to apply by hand — a keep that has already cleared noise-check,
regression-check, and representativeness-check is just... in the working tree, ready for him to look at or
commit.

**`--read-only`** (alt phrasing Douglas may use: "read only", "just report", "don't apply anything", "hand
back the diff", "don't touch the main tree"): restores the ORIGINAL hone behavior — every kept candidate is
proven inside its own throwaway worktree, the worktree is then removed, and the diff is reported for
Douglas to apply himself. Nothing ever touches the main tree. Reach for this when the target is
unfamiliar/high-risk enough that he wants to eyeball a performance change before it lands, or applying the
diff itself needs his own judgment call (e.g. it touches a shared/critical path).

If ARGUMENTS doesn't say which mode, use **Apply**. Douglas can always say "read-only" to switch, mid-request
or as a standing preference for a given ask.

**Interaction with `--mode plan|auto`:** this Apply/read-only toggle only matters for `--mode auto`.
`--mode plan` never creates a worktree or applies anything regardless (it stops right after the Opus
diagnostic pass, per Step 0) — `--read-only` is a no-op there. The two flags are independent: `--mode auto`
(default) + Apply (default) is hone's normal fully-autonomous path; `--mode auto --read-only` reproduces
hone's pre-existing behavior exactly; `--mode plan` is unaffected by either.

## What this is NOT

- Not `/tech-debt-audit` or `/solo-review` — those read code and reason about what *could* be slow; they
  never measure. `/hone` measures a real baseline and every trial against it. If a change can't be
  measured, it isn't a keep.
- Not `/spar` — `/spar` breaks correctness; `/hone` improves speed/memory while holding correctness. The
  regression check here exists to prove a speedup didn't quietly break the target, not to hunt new bugs.
- **Not for frontend/rendering work.** Paint/layout/reflow, bundle size, time-to-interactive, and Core
  Web Vitals belong to the `impeccable` design skill's own `/impeccable optimize`, which is purpose-built
  for that category. If the classification step lands on **frontend/rendering-bound (type 8)**, `/hone`
  DEFERS: it says so plainly and points Douglas at impeccable rather than duplicating it. (A backend/API
  latency that merely *feeds* a frontend is still in scope — the deferral is specifically for the render
  pipeline, the bundle, and the paint path.)

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone: what the code is, where it
lives (path), how to *run the slow thing* (the real command or entry point), and any existing
test/self-check entry point to prove correctness after a change. If ARGUMENTS lacks this and it isn't
obvious from the conversation, ask which target, how to run its slow path, and how to run its tests —
don't guess at a runnable workload. Parse `--max-iterations N` (default **6**) and an optional
`--budget` goal (e.g. "under 5 min", "peak RAM < 2 GB"); the budget is a stop condition, not a promise.
Parse `--read-only` per the Mode section above (default off, i.e. Apply mode).

**Parse `--mode plan|auto` (default `auto`).** This mode selects how far the run goes, and it is
load-bearing — it maps directly onto two rules Douglas already lives by:
- **`--mode plan`** honors his global "**Plan means plan — never implement**" rule. The ONLY output is a
  written plan: the Opus diagnostic work (classify + gate + baseline profile + ranked candidates) runs, then
  the run STOPS and returns the plan. **No Trial or Verify agent is called, and no worktree is ever created.**
  The plan prints a `--resume <runId>` handle; Douglas implements only on an explicit follow-up action verb
  (re-invoking with `--mode auto --resume <runId>`).
- **`--mode auto`** is his babysit-able autonomous mode (the same concept as `/longrun`'s auto mode): after
  the same diagnostic work, the run proceeds through the full measurement loop to completion **without
  stopping for approval** — the way he normally wants autonomous work to just proceed.

Also parse an optional `--resume <runId>`: when present, hand it to the Workflow as `resumeFromRunId` so a
prior `--mode plan` run's already-completed Opus profiling call replays from cache instead of re-running, and
the Workflow proceeds straight into the Trial/Verify loop. `--resume` is only meaningful with `--mode auto`
(resuming a plan into execution); a `--resume` with `--mode plan` just re-emits the cached plan.

### Step 1 — Classify the bottleneck type FIRST (mandatory, before any profiling)

Route the target to exactly one of these ten types. The tactic pool is chosen FROM the type — picking a
tactic before classifying is how tools waste an hour optimizing the wrong layer. If evidence is thin,
say which type you *suspect* and let the first profiling pass in Step 3 confirm or correct it.

1. **Algorithmic / compute-bound** — the code's own loops and data-structure choices are the hot path.
   Levers: better algorithm/data structure, memoization, hoist/kill redundant work.
2. **I/O-bound / network-bound** — waiting on disk/network/external APIs. Levers: batching, caching,
   async/concurrency, fewer round-trips.
3. **Database / query-bound** — a specialized I/O case: N+1 queries, missing indexes, bad joins. Levers:
   fix the query/index, batch, add a cache.
4. **Build / compile-time-bound** — source → runnable/testable artifact. Levers: incremental builds,
   artifact caching, parallelize independent compilation units.
5. **Test-suite-runtime-bound** — the automated suite's own wall-clock. Levers: parallelize independent
   tests, cache/skip unaffected ones, mock slow externalities.
6. **Startup / cold-start-bound** — import/init/JIT-warmup before the app is ready. Levers: lazy imports,
   defer heavy init, trim the import graph.
7. **Memory / resource-bound** — peak RAM, GC pressure, leaks, unclosed handles. A distinct failure mode
   from latency: it OOMs/crashes rather than merely being slow, so its "measurement" is peak memory or
   handle count, not elapsed time.
8. **Frontend / rendering-bound** — paint/layout/reflow, bundle size, TTI. **DEFER to impeccable's
   `/optimize`** (see "What this is NOT"). Report the classification and stop; do not profile it here.
9. **Concurrency-opportunity** — currently-serial work that is actually independent and parallelizable.
   *(Douglas's own real case: cad-forge's CAD gate was 25-28 min serial, cut to ~9 min by dispatching
   its 7 independent geometry leaves as concurrent processes — commit `a9884a3`, with a `GATE_SERIAL=1`
   env flag kept as the serial reference baseline.)* Lever: run the independent parts concurrently.
10. **Domain-kernel-bound** — the real hot path lives inside a heavy external library/kernel (CAD kernel,
    ML training step, video codec, physics sim) your own code barely touches. **The lever is NOT
    rewriting your code** — it's calling the kernel *smarter*: batch calls into it, parallelize
    independent kernel invocations, memoize/reuse built geometry, or pick a fundamentally different
    approach. This is cad-forge's actual category, and the reason the generic community perf tools don't
    fit it: they assume a fast, cheap local test command exists, which is false when one real build takes
    minutes. See Step 3's representative-slice fallback.

    **CAD / 3D-design-specific levers (all still type 10 — the cost lives inside the geometry kernel,
    OpenCascade/OCP, not your own code).** These are genuinely unique to CAD/3D and have no generic-software
    equivalent; reach for them when the target is a CAD build, exporter, gate, or assembly solver:
    - **Boolean-operation ORDER / tree-balancing.** Kernel `fuse`/`cut`/`common` ops scale poorly with part
      count and geometry complexity, and the *order* matters a lot. Fusing N small parts one at a time into
      a single growing result is much worse than fusing them in a **balanced pairwise tree** (fold pairs,
      then pairs of pairs). This is distinct from the generic "parallelize independent kernel calls" lever —
      it's about the *shape* of the boolean tree, not concurrency.
    - **Tessellation / mesh-deflection-tolerance tuning.** Any triangulated output — STL export, a rendered
      view, a mesh preview — is governed by **linear and angular deflection tolerance**. That's a direct
      triangle-count-vs-speed-vs-file-size knob: looser tolerance means far fewer triangles and a much faster
      tessellate/export, tighter means smoother-but-slower. There is no generic-software analogue; it's a real
      kernel dial worth measuring when the hot path is `triangulate`/`write_stl`/render.
    - **Parametric rebuild / regeneration caching.** A CAD assembly is a feature tree; changing one parameter
      can trigger a full **rebuild cascade** down the tree. The lever is caching unchanged sub-trees so only
      the affected features regenerate — an incremental rebuild tied to the CAD kernel's own regeneration
      model (this domain's version of build caching, but keyed on the feature graph, not a compiler).
    - **Assembly constraint / DOF-solver convergence.** Mating constraints and joint/interface graphs have
      their own **solver convergence and iteration-count** cost, separate from a generic "solver does work"
      view. The real levers are reducing the DOF count, removing over-constraint/redundant mates, or feeding
      the solver a **better initial guess** so it converges in fewer iterations.
    - **Batching spatial point-in-solid queries (a specialized spatial-query-bound case).** `BRepClass3d`
      point-in-solid checks are individually cheap but O(n) or worse in aggregate across many points per joint
      and many joints — exactly cad-forge's CAD-gate hardening pattern. Treat this the way a database N+1 is a
      specialized I/O case: **batch/vectorize the queries** where the kernel allows (build the classifier once
      per solid and reuse it across all points; group points by solid), rather than re-instantiating per point.
    - **STEP / export-import round-trip batching for standard parts.** Repeated single-part STEP import/export
      calls (e.g. the parts-cache fetching and round-tripping standard hardware) are a batchable, I/O-adjacent
      cost specific to **CAD interop formats** — not generic network I/O. The lever is batching the round-trips
      (one import/export pass over many parts, reuse of loaded shapes) rather than a per-part kernel call each
      time.

### Step 2 — The already-optimized / wrong-tool gate (mandatory, BEFORE profiling)

**First, check whether git history can even answer this question.** Run `git ls-files -- <target>` (or
`git check-ignore <target>`). If the target returns ZERO tracked files or is gitignored, an empty git log
means "cannot check" — NOT "no prior perf work exists." Say so explicitly: *"Target is untracked/gitignored:
git history cannot confirm prior perf work; the already-optimized gate is INCONCLUSIVE for this path"* and
proceed to classification without treating the silence as reassurance. (Real case: `dfm-explorable/` is
entirely gitignored at its repo root — a naive empty-log read would have silently waved a genuinely
already-optimized change straight past this gate.)

If the target IS tracked, check whether the work under study was already done. Run
`git log --oneline -30 -- <target-path(s)>` and `git log --stat --since="3 months ago" -- <target-path(s)>`
— **always scope with `-- <path>`**, not a bare repo-wide scan; on a multi-project repo an unscoped log
returns dozens of unrelated commits and buries the signal. Scan for commits that already addressed a
performance concern in this area (keywords: speed, faster, perf, parallel, cache, batch, optimize, memoize,
and the target's own file names). If found, that is the finding — report it plainly:

> *"Already optimized in commit `<hash>` — <what it did> (<measured delta if the commit states one>). No
> further action needed here."*

Do **not** manufacture a new, weaker finding to look useful. This gate is exactly what stops a naive pass
from re-discovering that cad-forge's `gate.py` was already made 3x faster two days prior. Also gate the
tool itself: if the classification is **frontend-bound (8)**, defer to impeccable and stop; if there is
genuinely no measurable slow path (the "slow" run is already sub-second and not in a hot loop), say
"nothing material to hone here" and stop rather than optimizing noise.

### Step 3 — The measurement state machine (per candidate)

The proven loop, one candidate change at a time:

**profile → propose ONE candidate → validate the plan → apply in an ISOLATED worktree → re-measure vs a
real recorded baseline → binary keep/discard on the number → log the experiment → repeat.**

- **Profile** to find *where* the time/memory actually goes (Python: `cProfile`/`pyinstrument`/`tracemalloc`;
  JS: the profiler or `--prof`/`clinic`; builds/tests/kernels: wall-clock the phases and per-call kernel
  time). Record a real **baseline** number before touching anything — the same command, measured, is the
  thing every trial is compared against.
- **No cheap test command? Profile a REPRESENTATIVE SLICE, and say so.** For **domain-kernel-bound (10)**
  and any target where the real run takes minutes, do NOT skip measurement — measure a representative
  *sample or slice* of the real workload (one part instead of the whole assembly; N iterations instead of
  the full epoch; a serial-reference flag like cad-forge's `GATE_SERIAL=1` as the control) and state
  explicitly that the number is a slice, plus why that slice is representative of the full run. A measured
  slice beats an unmeasured guess; a silent skip is forbidden.
  - **For CAD/3D targets, the slice is concrete, not abstract.** Prefer one of: **profile a SINGLE
    joint/part/leaf** instead of the whole assembly (one bolt's point-in-solid ring, one part's boolean
    subtree, one leaf of the gate) and multiply/extrapolate honestly; or run a **reduced-tessellation-tolerance
    pass** (loosen linear/angular deflection so the tessellate/export slice runs in seconds) to isolate where
    the triangulation cost lives before tuning it. Pick the slice that exercises the *classified* CAD lever —
    a single joint for point-in-solid/DOF work, a single boolean subtree for tree-balancing, a coarse
    tessellation pass for export/render — and say which one, and why it stands in for the full run.
- **Propose exactly ONE change**, drawn from the classified type's lever pool — never a bundle. One change
  per measurement is the only way the delta is attributable.
- **Validate the plan before applying:** does this change actually address the *classified* bottleneck
  type? (Caching an already-cheap compute step, or threading a GIL-bound CPU loop, or "optimizing" code
  when the time is inside the kernel — all fail this check.) If the proposed change doesn't target the
  measured hot path, discard it *before* spending the apply+measure cost and propose a different one.
- **Apply in an isolated git worktree — NEVER the caller's main tree.** Every trial change lives in its
  own throwaway worktree off the target's repo (see the Workflow script). The main working tree is never
  touched by Trial or Verify. Discarded trials are thrown away with their worktree. (The one deliberate
  exception is the post-Verify **Apply** step in Apply mode — see the Mode section above — which writes an
  already-adversarially-verified change to the main tree on purpose; that step runs strictly after Verify,
  never inside the Trial/Verify worktree.)
- **Re-measure** the same command/slice in the worktree, same conditions as the baseline.
- **Keep or discard on the number, binary.** Faster past a meaningful margin (see Step 4's noise check) →
  candidate keep. Not faster, or slower, or broke a test → discard, no rationalizing.
- **Log the experiment** every time, kept or discarded: what was tried, the before/after number, the
  delta, keep/discard, and why. The log is the deliverable even when nothing is kept.

### Step 4 — Adversarially verify every "it's faster" before it counts as a keep

A single fast run is not evidence. Before any candidate is reported as a **keep**, a skeptical second
pass must clear all three, or it drops back to discard:

1. **Not noise.** Re-run the benchmark **more than once** (both baseline and trial) and confirm the
   speedup exceeds the run-to-run variance — a delta inside the noise band is not a keep.
2. **Nothing broke.** Run the target's own existing tests / self-checks *after* the change, not just the
   timer. cad-forge's real bar here is "output verified byte-identical to the serial baseline" — a faster
   run that changes the answer is a regression, not a win.
3. **The benchmark is representative.** Confirm the input measured is real usage, not a toy that happens to
   exercise the fast path. If the win only shows on an unrepresentative input, say so and don't count it.

Only a change that survives all three is reported as a keep. Borrow the ethos from Douglas's
`panel-ultra-review` adversarial-verify step, aimed at performance claims instead of review findings.

## Safety constraints (apply every iteration, no exceptions)

- **Never run with elevated/bypass permissions.** A generic "make it fast" ask does not justify disabling
  the permission system; run at default tool permissions. If the classifier or a safety layer blocks an
  action mid-run, that is a correct block — narrow scope and try a different angle, don't route around it.
- **Stay strictly scoped to the target.** Profile and change only the target's own code path. No touching
  unrelated processes, files, services, or shared state; no destructive or irreversible action on
  anything shared.
- **Isolate ALL trial changes in a git worktree; never touch the caller's main tree — and PROVE isolation
  is possible before claiming it, never assume it.** `git worktree add` only carries COMMITTED content; an
  untracked file or an entirely un-gitted target directory does not exist in a fresh worktree at all. A run
  that assumes isolation without checking can silently edit the real target directly while still reporting
  "worktree removed" — a false safety claim. (Same class of bug found and fixed in `/probe` on 2026-07-07
  against `reviewer-app/`, which had no git repo of its own at the time.) Before the first Trial call, run
  the same check `/probe`'s Preflight phase does: confirm the target is inside a git working tree, its own
  content is actually tracked/committed (not just some ancestor directory), and — don't just infer this,
  prove it — actually `git worktree add` a scratch path and confirm the target's real files are present in
  it, then remove it. If that fails, STOP and ask Douglas (commit the target first — recommended — or
  proceed unisolated, in which case Trial applies changes directly to the main tree and must say so
  plainly, never "worktree removed"/"diff handed back" when that isn't what happened) rather than silently
  falling back. Each trial gets its own worktree; the caller's checkout and `git status` are left exactly
  as found.
- **Restore/clean up when done.** Remove every Trial/Verify worktree (`git worktree remove --force`) and
  prune, stop anything started, and confirm `git status` on the main tree shows nothing unexpected from
  those phases before finishing. **In Apply mode (default)**, a verified keep is then applied to the real
  main tree by the dedicated post-Verify Apply step (see Mode section) — that IS the intended change to
  `git status`, not something to clean up. **In `--read-only` mode**, a kept change is reported as a diff
  for Douglas to apply and is NOT left applied in the main tree, exactly as before this update. **Delete
  the throwaway branch with `git branch -d` (safe delete), not `-D`** — this machine's
  `block-dangerous-bash.js` hook unconditionally blocks `git branch -D` even for a disposable branch you
  created yourself in this same trial. Run worktree-remove and branch-delete as two separate calls, never
  chained in one command (a chained `-D` still trips the hook). If a throwaway branch genuinely can't be
  deleted (it has unique commits, or `-d` is refused), leave it and note the dangling pointer explicitly in
  the report rather than routing around the block.
- **No commits.** Honing means measuring, and in Apply mode applying a verified change to the working
  tree, but never `git commit`/`git push`, unless Douglas separately asked for that.
- **Make only the change each optimization attempt requires** — no unrelated refactors, no drive-by
  cleanup, no speculative abstractions beyond the one lever being measured. One change, one measurement.
- **If the target keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's
  `~/.claude` ↔ `claude-global-config` split), note it. In Apply mode, the post-Verify Apply step applies
  the change to the target's own tree only — it does NOT also edit the mirror; say so plainly and leave the
  mirror sync to Douglas (or a follow-up), since Apply's job is the one verified diff, not a second
  unverified copy of it. In `--read-only` mode, report the diff and let Douglas apply and mirror it himself.

## Procedure (how to run it)

1. Resolve TARGET, `mode`, `max_iterations`, `--budget`, and any `--resume <runId>` per Step 0.
2. **Run the gate FIRST (Step 2) yourself, before the Workflow** — `git log` is a cheap read and the
   whole point is to short-circuit before spending profiling time. If the gate fires (already optimized,
   frontend → defer to impeccable, or nothing material), report that and STOP — do not call the Workflow.
   (This gate short-circuit runs in BOTH modes; a fired gate is a valid plan-mode output too.)
3. Otherwise **call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<resolved target + how to run its slow path + how to run its tests>", classifiedType: "<1-10 label>", mode: "<plan|auto>", maxIterations: <N>, budget: "<goal or ''>", allowUnisolated: false, readOnly: <true if Douglas asked --read-only, else false> }`.
   In `mode: 'auto'`, the script runs a **Preflight** phase before Profile that actually creates (and
   removes) a scratch worktree to PROVE isolation is possible, rather than assuming it (plan mode skips this
   entirely — it never creates a worktree). If `stopReason` comes back `no_isolation_available`, this is
   Douglas's call, not yours: AskUserQuestion — commit the target first and re-run for full isolation
   (recommended), or proceed unisolated (Trial applies changes directly to the real files, no diff to hand
   back). Only re-invoke with `allowUnisolated: true` after he answers.
   If resuming, ALSO pass the Workflow's own `resumeFromRunId: "<runId>"` option so the completed Opus
   profiling call replays from cache. `resumeFromRunId` is a real Workflow tool option (it returns cached
   results for any completed `agent()` call whose prompt and opts are unchanged from the prior run); this
   script's `profilePrompt()` call does not vary its text or its `label` (`profile-i${i}`) based on `mode`,
   so a `--mode plan` run followed by `--mode auto --resume <runId>` is expected to correctly replay the
   Profile call from cache rather than re-running it on Opus. This has been verified by static inspection
   of the script and Workflow's documented resume behavior, not yet by a live end-to-end run — if a
   `--resume` invocation ever visibly re-runs the Profile phase instead of replaying it, that is worth
   flagging back rather than assuming the caching silently worked. This is an explicit skill-triggered
   Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   - **The Profile/classify/gate diagnostic work always runs first, in both modes, on `model: 'opus'`** —
     Douglas's delegation policy reserves Opus for the load-bearing judgment calls (classifying the
     bottleneck type, judging already-optimized, deciding which candidate levers actually address the
     measured hot path). The mechanical **Trial** and **Verify** phases stay on the default model.
   - **`mode: 'plan'`** → the Workflow returns right after the Opus diagnostic pass with the classification,
     gate outcome, baseline, and ranked candidates as a PLAN. It calls **no Trial or Verify agent and creates
     no worktree.** The returned `runId` is the `--resume` handle. Present the plan for Douglas to review.
   - **`mode: 'auto'`** (default) → after the same Opus diagnostic pass, the Workflow proceeds straight into
     the existing Trial/Verify loop with no pause, exactly as before this flag existed.
4. **Report the result** per "Final report" below, distinctly for the mode that ran. Never say "optimal" or
   "as fast as possible" — report the deltas actually measured this pass and what's still open, the way
   `/spar` reports "no new issues across the last 2 rounds" rather than "unbreakable."

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'hone',
  description: 'Measure-driven perf loop: preflight (prove isolation) -> Opus profiles+classifies+proposes (always first), then in mode=auto applies one change in an isolated worktree, re-measures vs baseline, keeps/discards on the number, adversarially verifies keeps, then (Apply mode, default) applies any verified keep to the real main tree; in mode=plan returns the ranked plan and stops (no worktree, no trial), resumable via resumeFromRunId; --read-only restores the original diff-handback-only behavior',
  phases: [
    { title: 'Preflight' },
    { title: 'Profile' },
    { title: 'Trial' },
    { title: 'Verify' },
    { title: 'Apply' },
  ],
}

const TARGET = args.target
const CLASSIFIED_TYPE = args.classifiedType || 'unclassified'
const MODE = args.mode === 'plan' ? 'plan' : 'auto'   // default auto; only 'plan' short-circuits
const MAX_ITERATIONS = args.maxIterations || 6
const BUDGET = args.budget || ''
const ALLOW_UNISOLATED = args.allowUnisolated === true
const READ_ONLY = args.readOnly === true   // default false = Apply mode; true restores the original diff-handback-only behavior

// --- Phase schemas (JSON-schema-validated agent output, spar.md pattern) ---

const PREFLIGHT_SCHEMA = {
  type: 'object',
  properties: {
    is_git_repo: { type: 'boolean' },
    target_tracked: { type: 'boolean' },
    can_isolate: { type: 'boolean' },     // true ONLY if a real worktree was created and PROVEN to contain the target's content, then removed
    reason: { type: 'string' },
  },
  required: ['is_git_repo', 'target_tracked', 'can_isolate', 'reason'],
}

const PROFILE_SCHEMA = {
  type: 'object',
  properties: {
    baseline_metric: { type: 'string' },        // e.g. "elapsed" or "peak_rss"
    baseline_value: { type: 'string' },          // the measured number + unit
    measured_on: { type: 'string', enum: ['full_run', 'representative_slice'] },
    slice_justification: { type: 'string' },     // required when measured_on = representative_slice
    hot_path: { type: 'string' },                // where the time/memory actually goes
    reclassify_to: { type: 'string' },           // '' if the Step-1 class held, else the corrected type
    candidates: {                                 // ranked lever ideas drawn from the classified type
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          lever: { type: 'string' },
          addresses_hot_path: { type: 'boolean' }, // the Step-3 plan-validation check
          rationale: { type: 'string' },
        },
        required: ['id', 'lever', 'addresses_hot_path'],
      },
    },
  },
  required: ['baseline_metric', 'baseline_value', 'measured_on', 'hot_path', 'candidates'],
}

const TRIAL_SCHEMA = {
  type: 'object',
  properties: {
    candidate_id: { type: 'string' },
    applied: { type: 'boolean' },                 // false if plan-validation rejected it before applying
    reject_reason: { type: 'string' },            // why it wasn't applied (didn't address hot path, unsafe, etc.)
    worktree_path: { type: 'string' },
    trial_value: { type: 'string' },              // re-measured number in the worktree, same conditions
    delta: { type: 'string' },                    // signed improvement vs baseline
    faster: { type: 'boolean' },                  // past a meaningful margin, pre-noise-check
    worktree_removed: { type: 'boolean' },        // MUST be true before finishing this trial (n/a when unisolated)
    applied_directly_to_main_tree: { type: 'boolean' }, // the honest disclosure flag for the unisolated path
    diff_summary: { type: 'string' },             // what the one change was
    diff: { type: 'string' },                     // the actual unified diff (e.g. `git diff` output) of the one change, so a later keep can be applied precisely
  },
  required: ['candidate_id', 'applied', 'worktree_removed'],
}

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    candidate_id: { type: 'string' },
    reran_count: { type: 'integer' },             // >1 required: noise check
    exceeds_variance: { type: 'boolean' },        // delta beats run-to-run noise
    tests_passed: { type: 'boolean' },            // target's own tests/self-checks after the change
    tests_evidence: { type: 'string' },
    input_representative: { type: 'boolean' },     // benchmark is real usage, not a toy
    verdict: { type: 'string', enum: ['keep', 'discard'] },
    reason: { type: 'string' },
    diff: { type: 'string' },                      // the exact diff re-confirmed during verification, for Apply to use
  },
  required: ['candidate_id', 'reran_count', 'exceeds_variance', 'tests_passed', 'input_representative', 'verdict'],
}

const APPLY_SCHEMA = {
  type: 'object',
  properties: {
    candidate_id: { type: 'string' },
    applied_to_main_tree: { type: 'boolean' },
    apply_method: { type: 'string' },              // e.g. "git apply", "manual edit matching the verified diff"
    tests_passed: { type: 'boolean' },              // target's own full test/self-check suite, re-run in the real main tree
    tests_evidence: { type: 'string' },
    reason_not_applied: { type: 'string' },         // set when applied_to_main_tree is false (patch conflict, etc.)
  },
  required: ['candidate_id', 'applied_to_main_tree', 'tests_passed'],
}

// --- Prompts ---

function preflightPrompt(target) {
  return `Before any profiling begins, PROVE whether git-worktree isolation is actually possible for this ` +
    `target -- Trial's whole safety guarantee depends on it, and assuming it works instead of proving it is ` +
    `exactly how a prior run (/probe, 2026-07-07) silently edited a real main tree while claiming isolation. ` +
    `TARGET: ${target}\n\n` +
    `Run real commands, don't infer: (1) is the target path inside a git working tree at all (\`git -C <dir> ` +
    `rev-parse --is-inside-work-tree\`)? (2) is the target's OWN content actually tracked/committed, not just ` +
    `some ancestor directory (\`git -C <dir> ls-files -- <path>\`)? (3) ACTUALLY attempt \`git worktree add ` +
    `<scratch> HEAD\` and confirm with your own eyes that the target's real files are present in it, then ` +
    `remove it (\`git worktree remove --force\`, then prune) so this check leaves no trace. Report ` +
    `is_git_repo, target_tracked, can_isolate (true ONLY if step 3 actually proved it), and reason in plain ` +
    `language if can_isolate is false.`
}

function profilePrompt(target, type, budget, priorLog) {
  return `You are profiling a performance target to find where the cost actually is. TARGET: ${target}\n\n` +
    `The bottleneck was pre-classified as type: ${type}. Confirm or correct that from the profile — set ` +
    `reclassify_to only if the measurement contradicts it.${budget ? ` The stated budget/goal is: ${budget}.` : ''}\n\n` +
    `RECORD A REAL BASELINE FIRST: run the slow path and measure it (elapsed, or peak memory for a ` +
    `memory/resource-bound target). If — and ONLY if — there is no fast, cheap way to run the full workload ` +
    `(e.g. a domain-kernel-bound build that takes minutes), measure a REPRESENTATIVE SLICE or SAMPLE instead ` +
    `(one part, N iterations, a serial-reference flag) and set measured_on='representative_slice' with a ` +
    `slice_justification explaining why that slice is representative. NEVER skip measurement silently.\n\n` +
    `Then profile to find the hot path, and propose a RANKED list of candidate changes — each drawn from the ` +
    `levers appropriate to the classified type, each marked addresses_hot_path (true only if it targets the ` +
    `measured hot path, not a cheap step). Do NOT apply anything yet. Do NOT bundle changes. Stay scoped to ` +
    `the target; no elevated permissions; leave git status clean.\n\n` +
    (priorLog.length ? `Experiments already tried this session (don't repeat, learn from them): ${JSON.stringify(priorLog)}\n\n` : '') +
    `Report: baseline_metric, baseline_value, measured_on (+ slice_justification if a slice), hot_path, ` +
    `reclassify_to (or ''), and the ranked candidates.`
}

function trialPrompt(target, baseline, candidate, isolated) {
  const isolationClause = isolated
    ? `Create a THROWAWAY GIT WORKTREE off the target's repo (git worktree add <tmp> HEAD) and make the ` +
      `change THERE. NEVER edit the caller's main working tree. CLEAN UP: remove the worktree ` +
      `(git worktree remove --force <tmp>) and prune; set worktree_removed=true only after you have ` +
      `confirmed it's gone and the main tree's git status is unchanged. Do NOT leave the change applied ` +
      `anywhere — report the diff_summary AND the actual diff (e.g. \`git diff\` output, captured before you ` +
      `remove the worktree) as \`diff\`, so a keep can be applied precisely later. Set ` +
      `applied_directly_to_main_tree=false.`
    : `NO GIT ISOLATION IS AVAILABLE for this target (preflight proved it and Douglas explicitly authorized ` +
      `proceeding anyway). Apply the change DIRECTLY to the real target files — there is no worktree and no ` +
      `diff-handback mechanism possible without one. State plainly which real files you modified. Do NOT ` +
      `claim a worktree was used. Set worktree_removed=false and applied_directly_to_main_tree=true.`;
  return `Apply and measure ONE candidate optimization. TARGET: ${target}\n` +
    `RECORDED BASELINE to beat: ${JSON.stringify(baseline)}\n` +
    `CANDIDATE: ${JSON.stringify(candidate)}\n\n` +
    `PLAN-VALIDATE FIRST: if this candidate does NOT actually address the measured hot path (or is unsafe / ` +
    `out of scope), set applied=false with a reject_reason and stop — do not spend the apply+measure cost.\n\n` +
    `If it passes: ${isolationClause}\n\n` +
    `Make ONLY the one change this candidate requires — no unrelated refactors or cleanup. Then RE-MEASURE ` +
    `the same command/slice under the same conditions as the baseline, and compute the signed delta. ` +
    `Set faster=true only if it beats the baseline by a meaningful margin. Do NOT commit.`
}

function verifyPrompt(target, baseline, trial) {
  return `Adversarially verify a claimed speedup before it counts as a KEEP. TARGET: ${target}\n` +
    `BASELINE: ${JSON.stringify(baseline)}\nTRIAL RESULT: ${JSON.stringify(trial)}\n\n` +
    `You are skeptical by default. Re-create the trial change (from trial.diff if present, else diff_summary) ` +
    `in a fresh throwaway worktree (never the main tree) and clear ALL THREE or the verdict is 'discard':\n` +
    `1. NOT NOISE — run BOTH baseline and trial more than once; confirm the delta exceeds run-to-run variance ` +
    `(set reran_count>1, exceeds_variance).\n` +
    `2. NOTHING BROKE — run the target's OWN existing tests/self-checks after the change (not just the timer); ` +
    `for a target with a known-good reference (e.g. a byte-identical serial baseline), confirm the output ` +
    `still matches. Set tests_passed + tests_evidence.\n` +
    `3. REPRESENTATIVE — confirm the measured input is real usage, not a toy that only exercises the fast ` +
    `path (input_representative).\n\n` +
    `If the verdict is 'keep', capture the exact diff you just verified (e.g. \`git diff\` output from this ` +
    `worktree, before you remove it) as \`diff\` — this is what a later Apply step will write to the real ` +
    `main tree, so it must be the precise, complete change, nothing more and nothing less.\n\n` +
    `Remove any worktree you created and leave the main tree's git status clean. Do not commit. Report ` +
    `verdict (keep only if all three hold) and reason.`
}

function applyPrompt(target, diff, testsHint) {
  return `A performance candidate has been ADVERSARIALLY VERIFIED as a genuine keep — it survived the noise ` +
    `check, the target's own tests, and the representativeness check, all inside an isolated worktree. Your ` +
    `job now is to apply that SAME verified change directly to the REAL target's main working tree. TARGET: ` +
    `${target}\n\nVERIFIED DIFF:\n${diff}\n\n` +
    `This is the ONE exception to hone's normal worktree-isolation rule: you are deliberately writing to the ` +
    `caller's actual checkout, not a worktree, because the change has already cleared verification. Apply the ` +
    `diff exactly — try \`git apply\` first; if it doesn't apply cleanly (context drift, etc.), reproduce the ` +
    `same change by hand, matching it precisely, with no additional edits, refactors, or cleanup beyond what ` +
    `the diff contains. If it genuinely can't be applied safely (conflicts, the target has moved on), do NOT ` +
    `force it or improvise a different change — set applied_to_main_tree=false with reason_not_applied, and ` +
    `leave the tree exactly as you found it.\n\n` +
    `If applied, re-run the target's own FULL existing test/self-test suite in the real main tree` +
    (testsHint ? ` (${testsHint})` : '') + ` to reconfirm nothing broke — this is a fresh check in the real ` +
    `tree, not a re-read of the worktree's earlier result. Do NOT commit or push — leave the change in the ` +
    `working tree for Douglas to review/commit himself. Report candidate_id, applied_to_main_tree, ` +
    `apply_method, tests_passed, tests_evidence, and reason_not_applied if it wasn't applied.`
}

// --- Loop ---

const experiments = []   // one entry per candidate tried, kept or discarded (the log deliverable)
const keeps = []
let baseline = null
let stopReason = null

// Plan mode never creates a worktree (it stops right after Profile), so isolation is irrelevant there --
// only check when mode=auto is actually going to run Trial/Verify.
let isolated = true
let preflight = null
if (MODE === 'auto') {
  log(`Preflight: proving whether git-worktree isolation is actually possible for ${TARGET}`)
  preflight = await agent(preflightPrompt(TARGET), { phase: 'Preflight', schema: PREFLIGHT_SCHEMA, label: 'preflight' })
  isolated = !!(preflight && preflight.can_isolate)
  if (!isolated && !ALLOW_UNISOLATED) {
    return {
      mode: 'auto', target: TARGET, isolated: false, preflight, stopReason: 'no_isolation_available',
      note: 'This target cannot be isolated in a git worktree (' +
        (preflight ? preflight.reason : 'the preflight agent did not return a usable result') + '). Hone ' +
        'refuses to silently fall back to editing the real tree. This needs Douglas\'s call: commit the ' +
        'target first and re-run for full isolation (recommended), or re-run with args.allowUnisolated=true ' +
        'to proceed without it (Trial will apply candidate changes directly to the real files with no ' +
        'worktree and no diff to hand back).',
    }
  }
  if (!isolated && ALLOW_UNISOLATED) {
    log('No isolation available -- proceeding UNISOLATED per explicit allowUnisolated=true. Trial changes will be applied directly to the real target, not handed back as a diff.')
  }
}

for (let i = 1; i <= MAX_ITERATIONS; i++) {
  log(`Iteration ${i}/${MAX_ITERATIONS}: profiling ${TARGET}`)
  // Opus for the load-bearing diagnostic judgment (classify / already-optimized / which lever hits the hot
  // path); the mechanical Trial + Verify phases below stay on the default model. On a --resume run this same
  // call replays from cache (Workflow's resumeFromRunId) instead of re-profiling.
  const prof = await agent(profilePrompt(TARGET, CLASSIFIED_TYPE, BUDGET, experiments), { phase: 'Profile', schema: PROFILE_SCHEMA, label: `profile-i${i}`, model: 'opus' })

  if (i === 1 && prof) baseline = { metric: prof.baseline_metric, value: prof.baseline_value, measured_on: prof.measured_on, slice_justification: prof.slice_justification || '' }
  if (prof && prof.reclassify_to) log(`Iteration ${i}: profile reclassified bottleneck to ${prof.reclassify_to}`)

  // PLAN MODE: the diagnostic work is done. Return the plan and STOP — no Trial, no Verify, no worktree.
  // "Plan means plan — never implement." Re-invoke with --mode auto and the printed --resume <runId> to
  // resume from this cached profile straight into the Trial/Verify loop.
  if (i === 1 && MODE === 'plan') {
    const rankedCandidates = (prof && prof.candidates) ? prof.candidates : []
    log(`Plan mode: diagnostic pass complete — returning ranked candidates as a PLAN, no trial applied`)
    return {
      mode: 'plan',
      target: TARGET,
      classifiedType: CLASSIFIED_TYPE,
      reclassifiedTo: (prof && prof.reclassify_to) || '',
      budget: BUDGET,
      baseline,
      hotPath: (prof && prof.hot_path) || '',
      rankedCandidates,
      hotPathCandidates: rankedCandidates.filter(c => c.addresses_hot_path),
      maxIterations: MAX_ITERATIONS,
      resumeHint: 're-invoke with --mode auto --resume <runId> (runId printed by the Workflow) to execute this plan; the Opus profiling call replays from cache',
      note: 'PLAN ONLY — no worktree created, no change applied, no trial run. Awaiting an explicit action verb to execute.',
    }
  }

  const candidates = (prof && prof.candidates) ? prof.candidates.filter(c => c.addresses_hot_path) : []
  if (candidates.length === 0) {
    stopReason = 'no_hot_path_candidate'
    log(`Iteration ${i}: no candidate addresses the measured hot path — stopping`)
    break
  }

  // Take the top-ranked hot-path candidate this iteration (one change at a time).
  const candidate = candidates[0]
  log(`Iteration ${i}: trialing candidate ${candidate.id} (${candidate.lever})`)
  const trial = await agent(trialPrompt(TARGET, baseline, candidate, isolated), { phase: 'Trial', schema: TRIAL_SCHEMA, label: `trial-i${i}` })

  if (!trial || !trial.applied) {
    experiments.push({ iteration: i, candidate, applied: false, reject_reason: trial ? trial.reject_reason : 'no trial result', verdict: 'discard' })
    log(`Iteration ${i}: candidate not applied (${trial ? trial.reject_reason : 'no result'})`)
    continue
  }

  if (!trial.faster) {
    experiments.push({ iteration: i, candidate, applied: true, trial_value: trial.trial_value, delta: trial.delta, verdict: 'discard', reason: 'not faster than baseline', worktree_removed: trial.worktree_removed, diff_summary: trial.diff_summary })
    log(`Iteration ${i}: not faster (${trial.delta}) — discarded`)
    continue
  }

  // Claimed faster -> adversarial verify before it counts.
  const verify = await agent(verifyPrompt(TARGET, baseline, trial), { phase: 'Verify', schema: VERIFY_SCHEMA, label: `verify-i${i}` })
  const kept = verify && verify.verdict === 'keep'
  const exp = { iteration: i, candidate, applied: true, trial_value: trial.trial_value, delta: trial.delta, verdict: kept ? 'keep' : 'discard', verify: verify || null, worktree_removed: trial.worktree_removed, diff_summary: trial.diff_summary }
  experiments.push(exp)

  if (!kept) {
    log(`Iteration ${i}: speedup did not survive verification (${verify ? verify.reason : 'no verify result'}) — discarded`)
    if (i === MAX_ITERATIONS) stopReason = 'max_iterations'
    continue
  }

  log(`Iteration ${i}: KEEP (${trial.delta}, verified)`)

  // Apply mode (default): write the verified diff directly to the REAL main tree and re-test it there.
  // Read-only mode: skip this entirely -- the diff stays a diff, exactly as before this update.
  if (!READ_ONLY) {
    const verifiedDiff = verify.diff || trial.diff || trial.diff_summary
    log(`Iteration ${i}: Apply mode -- writing the verified change to the main tree`)
    const applied = await agent(applyPrompt(TARGET, verifiedDiff, ''), { phase: 'Apply', schema: APPLY_SCHEMA, label: `apply-i${i}` })
    exp.apply = applied || null
    if (applied && applied.applied_to_main_tree) {
      log(`Iteration ${i}: applied to the main tree (tests_passed=${applied.tests_passed})`)
    } else {
      log(`Iteration ${i}: could NOT apply to the main tree (${applied ? applied.reason_not_applied : 'no apply result'}) -- falling back to diff handback`)
    }
  }

  keeps.push(exp)
  if (i === MAX_ITERATIONS) stopReason = 'max_iterations'
}

return {
  mode: 'auto',
  readOnly: READ_ONLY,
  target: TARGET,
  isolated,
  preflight,
  classifiedType: CLASSIFIED_TYPE,
  budget: BUDGET,
  baseline,
  maxIterations: MAX_ITERATIONS,
  iterationsRun: experiments.length ? Math.max(...experiments.map(e => e.iteration)) : 0,
  stopReason: stopReason || 'exhausted_candidates',
  experiments,
  keeps,
  totalTried: experiments.length,
  totalKept: keeps.length,
  totalApplied: keeps.filter(k => k.apply && k.apply.applied_to_main_tree).length,
}
```

## Final report (what to tell Douglas)

**Say which mode ran, and report the matching shape:**

**If `--mode plan` ran** — the deliverable is a WRITTEN PLAN, and nothing was executed. Report, and stop:
- The **gate outcome** (if it fired — a fired gate is a complete plan-mode answer on its own).
- The **classification** (which of the ten types) and whether the Opus profiling pass confirmed or corrected it.
- The **baseline** — the real recorded number, full-run vs representative-slice (with the slice justification).
- The **ranked candidate levers** the Opus pass proposed, each tagged whether it addresses the measured hot
  path, in priority order — this is the plan Douglas reviews.
- **State plainly that no worktree was created and no change was applied**, and give the resume line: re-invoke
  with **`--mode auto --resume <runId>`** (the `runId` the Workflow printed) to execute this plan — the
  completed Opus profiling call replays from cache instead of re-running, and the run proceeds straight into
  the Trial/Verify loop. Implementation waits for that explicit action verb.

**If `--mode auto` ran** — report the full measured loop, as below:

- **Gate outcome first.** If the Step-2 gate fired, that IS the report: *"already optimized in commit
  `<hash>` — <what it did>, no further action"*, or *"frontend-bound — deferred to impeccable's
  `/optimize`"*, or *"nothing material to hone here — <why>"*. Do not follow a fired gate with a
  manufactured finding.
- **Classification** — which of the ten types the target is, and whether the first profiling pass
  confirmed or corrected it.
- **Baseline** — the real recorded number, and whether it was the **full run** or a **representative
  slice** (with the slice justification, per the domain-kernel-bound path). Never present a slice as a
  full-run number.
- **Experiment log** — every candidate tried this pass, kept or discarded: the lever, before → after,
  the delta, and keep/discard **with the reason**. The discards matter as much as the keeps — they show
  what was ruled out and why.
- **Keeps** — for each surviving change: the measured delta, that it cleared all three adversarial checks
  (reran for noise, target's own tests passed, input representative), and:
  - **Apply mode (default):** whether it was successfully written to the real main tree, the apply method,
    and the tests_passed evidence from re-running the target's own suite there. A keep that couldn't be
    applied cleanly (patch conflict, target moved on) falls back to reporting the diff for Douglas to apply
    himself, with the reason stated plainly — never silently left half-applied.
  - **`--read-only`:** the **diff for Douglas to apply himself** — the change is NOT left applied in the
    main tree, exactly as before this update.
- **Honest close, mirroring `/tech-debt-audit` and `/spar`.** If nothing was kept, say so plainly:
  *"nothing material to keep this pass — <already optimized / not a fit for this tool / no change beat the
  baseline past noise>"* and why. Never claim the target is "optimal" or "as fast as possible" — report
  only what was measured this pass and what remains open (another `/hone` pass, or a lever that needs
  Douglas's judgment call). A required equivalent of the audit's "looks bad but is actually fine" section:
  list levers you considered and deliberately did NOT pursue, with the reason (already cheap, inside the
  kernel, unsafe in scope, needs Douglas's call).
- Full absolute path(s) of anything reported, per the standing Files-list convention. Confirm every trial
  worktree was removed and the main tree's `git status` is clean.

---

*Tracked copy: also save this file to `claude-global-config/commands/hone.md` (per the skills-are-tracked
convention) after a NASA scrub.*
