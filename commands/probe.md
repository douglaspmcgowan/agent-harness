---
name: probe
description: "Measured test-quality loop for any codebase (Python CAD/solver, JS/HTML, mixed). Synthesizes three distinct techniques into one pass: PROPERTY-BASED testing (infer a general rule a function must obey, then generate hundreds of randomized adversarial inputs to try to break it — Hypothesis for Python), MUTATION testing (inject small real bugs one at a time and re-run the EXISTING suite to see whether any test notices, reporting a killed/survived/total score — mutmut for Python), and COVERAGE-GAP FINDING AND WRITING (rank untested lines/branches by business-logic risk and actually WRITE new tests for the top gaps, each proven with red-green discipline). Runs a mandatory classification gate FIRST (no tests yet -> defer to TDD, not mutation-test an empty suite; pure I/O/config with no real invariants -> say so, don't manufacture a fake property), then coverage-gap scan -> property generation -> mutation score -> gap-writing -> honest report. Never claims 'fully tested' — reports what was verified this pass and what remains. Use when Douglas says 'probe', 'probe this', 'test-quality pass', 'are these tests any good', 'do the tests actually catch bugs', 'mutation test this', 'property test this', 'find and fill coverage gaps', '/probe'."
---

# /probe [target]

Test quality is a measured claim, never a felt one. A suite that passes 100% of its own tests proves the
tests agree with the code — not that either is correct. This command does not trust green. It infers the
rules a function must obey and throws hundreds of randomized adversarial inputs at them (property-based), it
injects real bugs one at a time to see whether the existing suite even notices (mutation), and it ranks the
untested code by risk and writes new tests for the worst gaps — each proven to fail-then-pass so it's known
to test something real. What survives is reported as verified this pass; what remains is named, never papered
over as "fully tested."

## What this is NOT

- **Not `/hone`.** `/hone` makes a test suite run FASTER (type 5, test-suite-runtime-bound) — a different
  axis entirely. `/probe` makes the suite (or the code) more EFFECTIVE at catching real bugs. A
  slow-but-thorough suite is `/probe`'s business; a fast-but-shallow suite is `/hone`'s. They don't overlap:
  `/hone` holds correctness constant and moves the clock; `/probe` holds the clock loosely and moves
  correctness-coverage.
- **Not `/spar`.** `/spar` is an open-ended live break-fix loop where a hostile agent tries to break ANY
  behavior of a running target and a fixer patches it, with a fresh adversary each round. `/probe` is the
  narrower, measured question of whether the codebase's TESTS — existing or newly written — actually verify
  correctness: property sweeps, a mutation score, coverage gaps filled. `/spar` attacks the running system;
  `/probe` interrogates the test suite. If Douglas wants a live adversary against behavior, point him at
  `/spar`.
- **Not `/tech-debt-audit`.** That's a one-shot narrative audit across nine dimensions, including a
  qualitative coverage-gap note. `/probe` is a dedicated, deeper, MEASURED pass on exactly one of those
  dimensions — test quality — with real numbers (a mutation score, property counterexamples, red-green-proven
  new tests) instead of a prose observation. It is not a general architecture review.
- **Not `superpowers:test-driven-development`.** TDD writes ONE hand-picked test BEFORE the implementation, in
  order, as a development discipline. `/probe` does not replace that discipline; it adds what TDD structurally
  cannot: randomized adversarial input generation (property-based) and a check on whether the EXISTING tests
  (however they were written) actually catch a real injected bug (mutation). If the target has NO tests at all
  yet, `/probe` says so plainly and points at TDD to write the first ones — it does not mutation-test an empty
  suite, which is meaningless (there is nothing to survive or be killed).

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone: what the code is, where it lives
(path), how to run its tests (the real `pytest`/`npm test`/equivalent command), and how to measure coverage
(`pytest --cov=<pkg>` or equivalent). If ARGUMENTS lacks this and it isn't obvious from the conversation, ask
which target, how to run its tests, and how to measure its coverage — don't guess at a runnable suite. If
Douglas named specific functions to focus the property sweep on (e.g. a numeric solver), carry those forward
as the priority targets for Step 4.

### Step 1 — Resolve the target's real test + coverage commands

Before anything expensive, establish the ground truth of the suite: find the test runner and coverage tool
the target actually uses (Python: `pytest` + `pytest-cov`; JS: whatever `package.json` scripts define),
confirm they run green on an unmodified checkout, and note the test file locations. A suite that doesn't even
run clean is its own finding — report that and stop rather than mutation-testing a red baseline.

### Step 2 — The classification gate (mandatory, BEFORE running anything expensive)

This gate mirrors `/hone`'s Step-2 gate: check the two conditions that make the expensive techniques
meaningless or fake BEFORE spending time on them.

1. **Zero existing tests?** If the target has no test suite at all, mutation testing is meaningless — there is
   nothing to kill or survive an injected bug. Say so plainly and **defer to `superpowers:test-driven-development`**
   to write the first tests, rather than running mutmut against nothing. Property-based generation and
   coverage-gap-writing can still add value here (they don't require a pre-existing suite), so note which of
   the three techniques still apply and which is deferred — don't silently run all three against an empty
   suite.
2. **Pure I/O / config / glue with no real invariants?** If the target is essentially I/O plumbing,
   configuration, or thin glue with no numeric or structural rule worth asserting, say so rather than
   manufacturing a fake property just to have run the property step. A property test that asserts a tautology
   is worse than none — it looks like coverage and verifies nothing. Report "no real invariants to
   property-test here" honestly and lean on mutation + coverage-gap instead.

If the gate fires on either condition, report it as the finding for that condition and route the remaining
applicable techniques — do not force a meaningless run to look thorough.

### Step 3 — Coverage-gap scan, ranked by risk (cheap and deterministic, so run it first)

Run the target's coverage tool (`pytest --cov=<pkg> --cov-report=term-missing` or equivalent) and collect the
untested lines and branches. Rank them by **business-logic risk**, not by line count:

> **business logic > data access > utilities > config**

A missed branch in a solver's feasibility check or a gate's accept/reject decision matters far more than an
untested logging helper. This scan is cheap and deterministic — it runs before the expensive generation and
mutation steps and feeds them: the highest-risk uncovered functions are exactly where Steps 4 and 6 should
aim. Report the ranked gap list; do not yet write tests (that's Step 6, after property + mutation have had a
chance to surface what actually breaks).

### Step 4 — Property-based generation for the numeric/boundary-sensitive functions

For the functions the coverage scan flagged as high-risk — and any Douglas named — that have a real invariant
(numeric solvers, encoders, geometry predicates, anything with a boundary), infer the general RULE the
function must obey and generate hundreds of randomized inputs to try to break it. This is the Trail of
Bits / Hypothesis technique: instead of one hand-picked case, assert a property and let the generator find
the adversarial edge cases a human would never hand-write. Real invariant shapes:

- **round-trip**: `decode(encode(x)) == x`
- **idempotence**: `sort(sort(x)) == sort(x)`
- **a physical/domain bound**: a computed mass, a stress, a member force should never go negative; a length
  should never exceed the model extent
- **order-invariance**: a result that should be identical regardless of equivalent input ordering

Use **Hypothesis** for Python targets (the equivalent generator for the target's actual language otherwise).
This is precisely the technique that would have caught Douglas's real `scipy.linprog(HiGHS)` bug in
`text-to-truss/truss-forge/truss/optimize.py`: the old primal-degenerate LP returned a different (sometimes
heavier-than-optimal) truss depending on member ordering — an order-invariance violation that only appeared at
specific numerical boundaries no one had hand-tested. If a property sweep finds a real counterexample, that is
a **HIGH-priority finding** — report the minimal failing input and the property it broke, prominently, because
it means a genuine bug is live in the code, not just a coverage gap.

### Step 5 — Mutation-test the existing suite for a real mutation score

Deliberately inject small, real bugs ("mutants") into the code one at a time and re-run the EXISTING test
suite to see whether any test notices. Report a **mutation score (killed / survived / total)** the same way a
gauge-repeatability study deliberately feeds a known-bad part through to confirm the gauge would flag it. A
suite that passes 100% of its own tests but doesn't kill an injected mutant is not actually verifying anything;
the surviving mutants point straight at the assertions the suite is missing. Use **mutmut** for Python (or the
equivalent for the target's actual language). This step directly targets Douglas's own documented
gate-honesty failure pattern: cad-forge's `accept.py` and `review_flaws.py` have both been caught rating a bad
build as clean — a surviving mutant in a gate's accept path is exactly that failure made visible. List the
surviving mutants (each is a place a real bug would go unnoticed) as findings ranked by the risk of the code
they live in.

### Step 6 — Write new tests for the highest-priority still-open gaps, with red-green proof

For the top gaps still open after Steps 3–5 — the highest-risk uncovered branches and the surviving mutants —
WRITE new tests, don't just report the gap. Verify each new test with **red-green discipline**: confirm it
FAILS against the pre-fix/reverted (or deliberately mutated) code and PASSES against the real code, so it's
proven to actually test something rather than being a tautology that passes no matter what. This red-green
proof doubles as a live mutation check on the new test itself — a test that can't be made to fail isn't
testing anything. Report each new test with its red-green evidence (the failing output, then the passing
output); a new test without that proof does not count as written.

### Step 7 — The honest final report

Report, in the register of `/spar` and `/hone` (measured, non-fabricating):

- The **gate outcome** — did either gate condition fire (no tests -> deferred to TDD; no real invariants ->
  no property test manufactured), and which techniques ran vs. were correctly skipped.
- The **coverage gaps** — ranked by risk, which were addressed this pass and which remain open.
- Any **property-test counterexamples** — the real bugs found, if any, with the minimal failing input and the
  property broken. If none were found, say "no counterexample found across the sweep this pass," NOT "the
  function is correct."
- The **mutation score** — killed / survived / total, with the surviving mutants listed as the concrete gaps
  in the suite's assertions.
- The **new tests written** — each with its red-green proof; and the gaps still open that were not written
  this pass.
- **Never "fully tested."** Mirror `/hone`'s "no change beat the baseline past noise this pass" and `/spar`'s
  "no new issues found across the last 2 rounds": report what was verified THIS pass and what remains, not a
  guarantee of correctness. "Unbreakable," "fully tested," and "100% covered" are banned framings — a mutation
  score and a coverage number are measurements, not certificates.
- **Isolation status, stated plainly, every time — never assumed.** State whether the run was isolated
  (worktree proven, nothing touched the main tree) or unisolated (no repo / target untracked, Douglas
  explicitly authorized proceeding anyway, changes applied directly to the real files). Never say "worktree
  removed" or "handed back as a diff" unless isolation was actually proven this run — copying that language
  from the isolated-mode template when it didn't apply is exactly the failure this command had on 2026-07-07.
- Full absolute path(s) of anything changed or written, per the standing Files-list convention.

## Safety constraints (apply every run, no exceptions)

- **Never run with elevated/bypass permissions.** A generic "test this thoroughly" ask does not justify
  disabling the permission system; run at default tool permissions. If the classifier or a safety layer blocks
  an action mid-run, that is a correct block — narrow scope and try a different angle, don't route around it.
- **Isolate ALL work in a git worktree; never touch the caller's main tree — and PROVE isolation is actually
  possible before claiming it, never assume it.** `git worktree add` only carries COMMITTED content; an
  untracked file or an entirely un-gitted directory does not exist in a fresh worktree at all. A run that
  assumes isolation without checking can silently fall back to editing the real target directly while still
  reporting "worktree removed, diff handed back" — a false safety claim, not a degraded run.
  (Found 2026-07-07: exactly this happened against `reviewer-app/`, an untracked folder with no git repo of
  its own — the write phase edited `reviewer-server.js` directly in the main tree while the final report
  claimed full worktree isolation and a handed-back diff. The workflow script below now has a mandatory
  Preflight phase that actually creates and proves a worktree before any mutation-risk work runs, and refuses
  to silently degrade — see the Preflight step and `args.allowUnisolated`.) Mutation testing edits the code,
  and writing/proving new tests reverts and re-applies changes — all of that lives in a throwaway worktree off
  the target's repo, never the caller's checkout. The main working tree and its `git status` are left exactly
  as found.
- **If preflight finds isolation is NOT possible (no repo, or the target is untracked), STOP and ask Douglas
  before proceeding — do not silently fall back to editing the main tree.** This is a call only he can make
  (AskUserQuestion: "isolate by committing the target first" vs. "proceed without isolation, accepting the
  target gets edited directly"). Only re-run with `args.allowUnisolated: true` after he has explicitly said so.
  Even then: **mutation testing never runs unisolated, full stop** — it injects broken code with no git-backed
  revert path, which is unacceptably risky without a worktree. Coverage-gap scanning and property sweeps are
  non-destructive (read + call only) and may run unisolated. Write-and-prove may run unisolated only with
  `allowUnisolated: true`, and its report must say plainly "applied directly to the main tree, no worktree, no
  diff to hand back" — never reuse the isolated-mode language ("worktree removed", "diff handed back") when
  that isn't what happened.
- **Clean up when done.** Remove every worktree (`git worktree remove --force`) and prune, and confirm
  `git status` on the main tree shows nothing unexpected before finishing. **Delete a throwaway branch with
  `git branch -d` (safe delete), not `-D`** — this machine's `block-dangerous-bash.js` hook unconditionally
  blocks `git branch -D`. Run worktree-remove and branch-delete as two separate calls, never chained. If a
  branch genuinely can't be `-d`-deleted, leave it and note the dangling pointer in the report rather than
  routing around the block.
- **New tests are handed back for Douglas to apply — not left applied in the main tree.** A written test that
  cleared red-green is reported as a diff (with its proof), the same way `/hone` hands back a kept change. Do
  not commit. Mutation-testing edits and reverted-code checks NEVER persist — they exist only inside the
  worktree for the duration of the measurement.
- **No commits.** Probing means measuring, writing-and-proving tests, and reporting — never `git commit` /
  `git push`, unless Douglas separately asked for that.
- **Make only the changes the technique requires** — new tests for real gaps, mutants for scoring. No
  unrelated refactors, no drive-by cleanup, no rewriting the code under test (that's `/spar`'s job, not this
  one). If a surviving mutant reveals a real code bug, report it as a finding for Douglas — don't silently
  patch the implementation here.
- **If the target keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's
  `~/.claude` ↔ `claude-global-config` split), note it — but still do not apply new tests to either; report
  the diff and let Douglas apply and mirror it.

## Procedure (how to run it)

1. Resolve TARGET, its test command, and its coverage command per Step 0.
2. **Call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<resolved target + how to run its tests + how to measure coverage>", focusFunctions: "<any functions Douglas named, or ''>", allowUnisolated: false }`.
   This is an explicit skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   - **The classification gate + technique-selection judgment runs on `model: 'opus'`** — Douglas's delegation
     policy reserves Opus for the load-bearing calls (deciding whether the gate fires, which invariant a
     numeric function actually has, whether a surviving mutant reflects a real bug). The mechanical coverage
     scan, mutation run, and test-writing phases stay on the default model.
   - The workflow's first phase always runs a **Preflight** that actually creates (and removes) a scratch
     worktree to PROVE isolation is possible, rather than assuming it. If `stopReason` comes back
     `no_isolation_available`, do not re-run with `allowUnisolated: true` on your own judgment — this is
     Douglas's call. Use AskUserQuestion: isolate by committing the target first (recommended — re-run `/probe`
     once it's committed, full isolation, no compromise), or proceed unisolated (mutation testing will be
     skipped entirely; coverage-gap scan, property sweeps, and write-and-prove may still run, but any new
     tests get applied directly to the real files with no worktree and no diff to hand back). Only re-invoke
     Workflow with `allowUnisolated: true` after he answers.
3. **Report the result** per Step 7 / "Final report" below. Never claim "fully tested" — report the mutation
   score, coverage gaps addressed vs. still open, and any property counterexamples actually found this pass.
   State the isolation status plainly (see Step 7) — do not repeat the workflow's own summary language without
   checking `isolated`/`preflight` in the returned object first.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'probe',
  description: 'Measured test-quality loop: preflight (prove isolation) -> gate (no-tests/no-invariants) -> coverage-gap scan -> property-based generation -> mutation score -> write-and-prove new tests -> honest report',
  phases: [
    { title: 'Preflight' },
    { title: 'Gate & Scan' },
    { title: 'Property' },
    { title: 'Mutation' },
    { title: 'Write & Prove' },
  ],
}

const TARGET = args.target
const FOCUS = args.focusFunctions || ''
const ALLOW_UNISOLATED = args.allowUnisolated === true

// --- Phase schemas (JSON-schema-validated agent output, spar.md/hone.md pattern) ---

const PREFLIGHT_SCHEMA = {
  type: 'object',
  properties: {
    is_git_repo: { type: 'boolean' },     // TARGET path is inside SOME git working tree
    target_tracked: { type: 'boolean' },  // TARGET's own content is committed/tracked, not just a parent dir
    can_isolate: { type: 'boolean' },     // true ONLY if a real worktree was created and PROVEN to contain the target's content, then removed
    reason: { type: 'string' },           // plain language -- especially why can_isolate is false, if it is
  },
  required: ['is_git_repo', 'target_tracked', 'can_isolate', 'reason'],
}

const GATE_SCHEMA = {
  type: 'object',
  properties: {
    baseline_green: { type: 'boolean' },              // suite runs clean on an unmodified checkout
    no_tests_yet: { type: 'boolean' },                 // gate condition 1
    no_real_invariants: { type: 'boolean' },           // gate condition 2 (pure I/O/config/glue)
    gate_note: { type: 'string' },                     // what fired, and why, in plain language
    techniques_to_run: {                                // which of the three still apply after the gate
      type: 'array',
      items: { type: 'string', enum: ['coverage_gap', 'property', 'mutation'] },
    },
    coverage_gaps: {                                    // ranked by business-logic risk, cheap + deterministic
      type: 'array',
      items: {
        type: 'object',
        properties: {
          location: { type: 'string' },
          risk: { type: 'string', enum: ['business_logic', 'data_access', 'utility', 'config'] },
          note: { type: 'string' },
        },
        required: ['location', 'risk'],
      },
    },
    property_candidates: {                              // functions with a real invariant worth sweeping
      type: 'array',
      items: {
        type: 'object',
        properties: {
          fn: { type: 'string' },
          invariant: { type: 'string' },                // round-trip / idempotence / physical-bound / order-invariance
        },
        required: ['fn', 'invariant'],
      },
    },
  },
  required: ['baseline_green', 'no_tests_yet', 'no_real_invariants', 'gate_note', 'techniques_to_run'],
}

const PROPERTY_SCHEMA = {
  type: 'object',
  properties: {
    fn: { type: 'string' },
    invariant: { type: 'string' },
    runs: { type: 'integer' },                          // how many randomized inputs were actually generated
    counterexample_found: { type: 'boolean' },
    minimal_failing_input: { type: 'string' },          // required if counterexample_found
    property_violated: { type: 'string' },
    evidence: { type: 'string' },
  },
  required: ['fn', 'invariant', 'runs', 'counterexample_found'],
}

const MUTATION_SCHEMA = {
  type: 'object',
  properties: {
    tool_used: { type: 'string' },                      // mutmut or equivalent
    killed: { type: 'integer' },
    survived: { type: 'integer' },
    total: { type: 'integer' },
    surviving_mutants: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          location: { type: 'string' },
          mutation: { type: 'string' },
          why_it_matters: { type: 'string' },
        },
        required: ['location', 'mutation'],
      },
    },
  },
  required: ['tool_used', 'killed', 'survived', 'total', 'surviving_mutants'],
}

const WRITE_SCHEMA = {
  type: 'object',
  properties: {
    tests_written: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          target_gap: { type: 'string' },
          test_name: { type: 'string' },
          red_evidence: { type: 'string' },             // failed against reverted/mutated code
          green_evidence: { type: 'string' },            // passed against real code
          diff: { type: 'string' },
          proven: { type: 'boolean' },                   // false if red-green couldn't be demonstrated -- doesn't count
        },
        required: ['target_gap', 'test_name', 'proven'],
      },
    },
    worktree_removed: { type: 'boolean' },                // only meaningful when isolated -- false/n-a when unisolated
    applied_directly_to_main_tree: { type: 'boolean' },   // the honest disclosure flag for the unisolated path
    still_open_gaps: { type: 'array', items: { type: 'string' } },
  },
  required: ['tests_written', 'worktree_removed', 'applied_directly_to_main_tree', 'still_open_gaps'],
}

// --- Prompts ---

function preflightPrompt(target) {
  return `Before any test-quality work begins, PROVE whether git-worktree isolation is actually possible for ` +
    `this target -- this command's entire safety guarantee depends on it, and assuming it works instead of ` +
    `proving it is exactly how a prior run silently edited a real main tree while claiming full isolation. ` +
    `TARGET: ${target}\n\n` +
    `Do not infer from reading paths -- run real commands:\n` +
    `1. Is the target path inside a git working tree at all? (\`git -C <dir> rev-parse --is-inside-work-tree\`)\n` +
    `2. Is the target's OWN content actually tracked/committed, not just some ancestor directory? ` +
    `(\`git -C <dir> ls-files -- <path>\` should return real files; \`git -C <dir> status --porcelain -- <path>\` ` +
    `showing \`??\` for everything means it's untracked). An untracked file or directory is NOT carried into a ` +
    `fresh \`git worktree add\` -- the new worktree simply won't contain it, silently defeating isolation.\n` +
    `3. ACTUALLY attempt \`git worktree add <scratch-path> <branch-or-HEAD>\` and confirm with your own eyes ` +
    `(ls / Read) that the target's real files are genuinely present in the new worktree -- don't just infer ` +
    `from steps 1-2, prove it by doing it. Remove the scratch worktree afterward either way ` +
    `(\`git worktree remove --force\`, then prune) so this check leaves no trace.\n\n` +
    `Report is_git_repo, target_tracked, can_isolate (true ONLY if you performed step 3 and confirmed the ` +
    `target's content was actually present in the new worktree), and reason in plain language -- if can_isolate ` +
    `is false, say exactly why (no repo at all / repo exists but target is untracked / worktree created but was ` +
    `empty / other, specifically what).`
}

function gatePrompt(target, focus) {
  return `You are running the mandatory classification gate and initial coverage scan for a test-quality pass. ` +
    `TARGET: ${target}\n\n` +
    `First, confirm the target's existing test suite runs GREEN on an unmodified checkout (set baseline_green). ` +
    `If it doesn't run clean, stop and report that as the finding -- do not proceed to mutation-test a red baseline.\n\n` +
    `Then check the two gate conditions, in ISOLATION (a throwaway git worktree off the target's real repo -- ` +
    `never the caller's main tree; leave it clean and removed when you finish this phase):\n` +
    `1. NO TESTS YET -- if there is no existing test suite at all, mutation testing is meaningless (nothing to ` +
    `kill or survive). Set no_tests_yet=true and note that TDD should write the first tests -- property-based ` +
    `and coverage-gap-writing can still run without a pre-existing suite, so don't blanket-skip everything.\n` +
    `2. NO REAL INVARIANTS -- if the target is pure I/O/config/glue with nothing worth asserting as a general ` +
    `rule, set no_real_invariants=true rather than inventing a tautological property.\n\n` +
    `Then run the target's real coverage tool (pytest --cov=<pkg> --cov-report=term-missing or equivalent) and ` +
    `list untested lines/branches, ranked by risk: business_logic > data_access > utility > config -- not by ` +
    `line count. A missed branch in a solver's feasibility check or a gate's accept/reject decision outranks an ` +
    `untested logging helper.\n\n` +
    `Finally, from the coverage scan (plus anything Douglas named: "${focus}"), identify which functions have a ` +
    `REAL invariant worth a property sweep (round-trip, idempotence, a physical/domain bound, order-invariance) ` +
    `-- do not force one onto a function that doesn't have one.\n\n` +
    `Set techniques_to_run to exactly the subset of ['coverage_gap','property','mutation'] that actually apply ` +
    `given the gate outcome. Report baseline_green, no_tests_yet, no_real_invariants, gate_note (plain-language ` +
    `explanation of what fired), coverage_gaps (ranked), and property_candidates.`
}

function propertyPrompt(target, candidate) {
  return `Run a property-based sweep against ONE function, in an isolated throwaway git worktree (never the ` +
    `caller's main tree). TARGET: ${target}\nFUNCTION: ${candidate.fn}\nCLAIMED INVARIANT: ${candidate.invariant}\n\n` +
    `Use Hypothesis (Python) or the equivalent generator for the target's actual language. Generate hundreds of ` +
    `randomized inputs -- including adversarial edge cases (empty, negative, huge, boundary-exact values) a ` +
    `human would never hand-write -- and try to find one that breaks the stated invariant. Report the exact ` +
    `number of runs actually generated (not a guess). If you find a genuine counterexample, report the MINIMAL ` +
    `failing input and exactly which property it violates -- this is a HIGH-priority finding, a real bug, not ` +
    `just a coverage gap. If none is found after a genuine sweep, say so plainly (counterexample_found=false) -- ` +
    `do not claim the function is "correct," only that no counterexample turned up this pass. Remove your ` +
    `worktree when done; leave the main tree untouched.`
}

function mutationPrompt(target) {
  return `Run mutation testing against the target's EXISTING test suite, in an isolated throwaway git worktree ` +
    `(never the caller's main tree). TARGET: ${target}\n\n` +
    `Use mutmut (Python) or the equivalent for the target's actual language. Inject small, real mutants one at a ` +
    `time (flip a comparison, change a boundary, invert a condition) and re-run the existing suite against each ` +
    `to see whether any test notices. Report killed/survived/total counts. For each SURVIVING mutant, name its ` +
    `location, what the mutation was, and why it matters (a surviving mutant in an accept/reject gate path is ` +
    `exactly the kind of silent-pass failure Douglas has been bitten by before -- flag those specifically). ` +
    `Remove your worktree and confirm the main tree's git status is unchanged when done. Do not commit.`
}

function writePrompt(target, openGaps, survivingMutants, isolated) {
  const isolationClause = isolated
    ? `Do this in an isolated throwaway git worktree (never the caller's main tree). Remove the worktree when ` +
      `done (never leave a new test applied in the main tree -- it's handed back as a diff for Douglas to apply ` +
      `himself). Set worktree_removed=true and applied_directly_to_main_tree=false.`
    : `NO GIT ISOLATION IS AVAILABLE for this target (preflight proved it and Douglas explicitly authorized ` +
      `proceeding anyway). There is no worktree to isolate in and no diff-handback mechanism possible without ` +
      `one -- apply new tests DIRECTLY to the real target files. State this plainly and prominently: exactly ` +
      `which real files you modified. Do NOT claim a worktree was used or a diff was handed back -- that would ` +
      `be false in this mode. Set worktree_removed=false and applied_directly_to_main_tree=true.`;
  return `Write new tests for the highest-priority still-open gaps. TARGET: ${target}\n` +
    `OPEN COVERAGE GAPS: ${JSON.stringify(openGaps)}\nSURVIVING MUTANTS: ${JSON.stringify(survivingMutants)}\n\n` +
    `${isolationClause}\n\n` +
    `For the top few gaps/mutants (don't try to close everything in one pass -- pick the highest-risk ones), ` +
    `write a new test and PROVE it with red-green discipline: run it against the reverted/pre-fix (or ` +
    `deliberately mutated) code and confirm it FAILS, then run it against the real code and confirm it PASSES. ` +
    `A test without this red-green proof does not count as written -- do not report it as a completed test. ` +
    `Report each proven test with its red/green evidence and a diff. Do not commit. List any gaps you ` +
    `deliberately left open this pass (out of scope, needs Douglas's judgment call, etc).`
}

// --- Run ---

log(`Preflight: proving whether git-worktree isolation is actually possible for ${TARGET}`)
const preflight = await agent(preflightPrompt(TARGET), { phase: 'Preflight', schema: PREFLIGHT_SCHEMA, label: 'preflight' })
const isolated = !!(preflight && preflight.can_isolate)

if (!isolated && !ALLOW_UNISOLATED) {
  return {
    target: TARGET,
    isolated: false,
    preflight,
    stopReason: 'no_isolation_available',
    note: 'This target cannot be isolated in a git worktree (' +
      (preflight ? preflight.reason : 'the preflight agent did not return a usable result') + '). Probe ' +
      'refuses to silently fall back to editing the real tree. This needs Douglas\'s call: commit the target ' +
      'first and re-run for full isolation (recommended), or re-run with args.allowUnisolated=true to proceed ' +
      'without it (mutation testing will be skipped entirely; write-and-prove will apply directly to the real ' +
      'files with no worktree and no diff to hand back).',
  }
}
if (!isolated && ALLOW_UNISOLATED) {
  log('No isolation available -- proceeding UNISOLATED per explicit allowUnisolated=true. Mutation testing will be skipped (no git-backed revert path for injected mutants). Any new tests will be applied directly to the real target, not handed back as a diff.')
}

log(`Running gate + coverage scan for ${TARGET}`)
const gate = await agent(gatePrompt(TARGET, FOCUS), { phase: 'Gate & Scan', schema: GATE_SCHEMA, label: 'gate-scan', model: 'opus' })

if (!gate || !gate.baseline_green) {
  return {
    target: TARGET,
    isolated,
    preflight,
    stopReason: 'baseline_not_green',
    note: 'The existing suite does not run clean on an unmodified checkout -- fix that first; a red baseline makes mutation testing meaningless.',
    gate,
  }
}

const runProperty = (gate.techniques_to_run || []).includes('property') && !gate.no_real_invariants
// Mutation testing injects broken code with no safe revert path outside a worktree -- never runs unisolated,
// regardless of allowUnisolated (see Safety constraints in probe.md).
const runMutation = (gate.techniques_to_run || []).includes('mutation') && !gate.no_tests_yet && isolated

let propertyResults = []
if (runProperty && gate.property_candidates && gate.property_candidates.length) {
  log(`Property-based sweep on ${gate.property_candidates.length} candidate(s)`)
  propertyResults = await parallel(gate.property_candidates.map(c => () =>
    agent(propertyPrompt(TARGET, c), { phase: 'Property', schema: PROPERTY_SCHEMA, label: `property-${c.fn}`, model: 'opus' })
  ))
}

let mutation = null
if (runMutation) {
  log('Mutation-testing the existing suite')
  mutation = await agent(mutationPrompt(TARGET), { phase: 'Mutation', schema: MUTATION_SCHEMA, label: 'mutation' })
}

const openGaps = (gate.coverage_gaps || []).filter(g => g.risk === 'business_logic' || g.risk === 'data_access')
const survivingMutants = mutation ? mutation.surviving_mutants : []

let write = null
if (openGaps.length || survivingMutants.length) {
  log('Writing and proving new tests for the highest-priority open gaps')
  write = await agent(writePrompt(TARGET, openGaps, survivingMutants, isolated), { phase: 'Write & Prove', schema: WRITE_SCHEMA, label: 'write-prove' })
}

return {
  target: TARGET,
  isolated,
  preflight,
  gate,
  techniquesRun: {
    coverage_gap: true,
    property: runProperty,
    mutation: runMutation,
  },
  propertyResults,
  mutation,
  write,
  stopReason: 'complete',
}
```

---

*Tracked copy: also save this file to `claude-global-config/commands/probe.md` (per the skills-are-tracked
convention) after a NASA scrub.*
