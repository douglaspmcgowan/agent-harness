# Solo Review

Single-subagent version of `panel-ultra-review`: ONE subagent does an exhaustive, open-ended pass, finds
issues, and — by default — **fixes them immediately**. Works on a general codebase OR a CAD/structural model
output (STEP files, gate/accept JSON, connections/joint registries) — same raw-find approach, no multi-model
panel, no bucketing, no seams pass, no merge step. Trades the found-by-N consensus/severity signal for speed
and cost. Composes three of Claude Code's own built-in skills as additional steps rather than reimplementing
their logic — `code-review` as a second finder, `verify` as a runtime ground-truth check, and `simplify` as a
post-fix cleanup pass gated to Apply mode only (see their own steps below).

**"Solo" means one MODEL and no multi-model panel — it does NOT mean one agent.** It already fans out several
agents (an open-ended raw finder, the built-in `code-review`, a runtime `verify`, and a fixer), and this
version adds a second review AXIS (Step 3c). What solo-review trades away vs `panel-ultra-review` is model
*diversity* (the found-by-N consensus a cross-model panel gives), not agent count — one model, as many agents
and passes as the review needs.

## Mode (read this first)

**Default: APPLY.** Find issues, then fix them immediately — root-cause each one, TDD discipline (red-green)
where the target has a real test harness, verify the target's own test/build/gate suite doesn't regress, and
report a disposition (fixed/skipped/wont_fix) per finding. Nothing is left as a report Douglas has to act on
by hand — the fixes are already in the working tree, verified, ready for him to look at or commit. Apply mode
also runs the composed `verify` and `simplify` skills (Steps 5 and 8 below) — `verify` re-checks the fix at
the runtime/app level, `simplify` is the one composed skill exclusive to this mode since it mutates code.

**`--read-only`** (alt phrasing Douglas may use: "read only", "just report", "don't fix anything yet", "review
only", "no edits"): find issues and write a report only — the ORIGINAL solo-review behavior. No edits, no
writes, no mutating scripts. Reach for this when he wants eyes-on before any edit lands, the codebase is
unfamiliar/high-risk enough that he wants to steer which findings get fixed, or the target is a CAD/model
output where "fixing" a finding could mean a threshold/gate judgment call only he should make (see the CAD
safety clause below — apply mode never takes that shortcut on its own, but read-only lets him triage first
regardless). The composed `code-review` and `verify` skills (Steps 3b and 5 below) still run in this mode —
both are read-only by design, so they fit this mode's own contract. The composed `simplify` skill (Step 8)
never runs here: it mutates code by design, which read-only mode's own contract forbids.

If ARGUMENTS doesn't say which mode, use **Apply**. Douglas can always say "read-only" to switch, mid-request
or as a standing preference for a given ask.

## When to use this vs `panel-ultra-review`

- **Use solo-review** when the ask is a quick look, cost/time matters more than consensus, or the target
  (codebase or model output) is small enough for one agent's context.
- **Use `panel-ultra-review` instead** when the user says "ultra", "exhaustive", "audit", "thorough", or the
  codebase spans enough subsystems that one context window can't hold it — that skill's cross-model panel and
  dedicated seams pass exist because a single reviewer is blind to inter-module drift, and ~40% of issues in
  panel data were found by exactly one model even with a full panel. A single agent here will still find real,
  actionable issues — it just won't tell you which ones are load-bearing (found-by-all) vs a single lens's
  guess (found-by-one, unverified). `panel-ultra-review` stays read-only + issues-and-plans regardless of what
  solo-review's default is — it's a different skill with its own contract, not affected by this change.

**Two failure categories this open-ended pass under-covers by design:** OBS/CONFIG (config-validation at the
boundary, secrets-in-logs, structured logging, failure instrumentation) and CONCURRENCY/IDEMPOTENCY (lost-update
read-modify-write, idempotency under retries, TOCTOU/write-skew) are steady-state properties a single diff-shaped
pass reads past. When the target is a load-bearing service and either category matters, run `/review-lenses` (its
two canon-grounded lens prompts, severity rubric, and per-finding evidence requirement) as a focused complement —
either as a Step-3 additional lens or as its own scheduled sweep.

## Procedure

1. **Determine target type.** Codebase (source files) or CAD/structural model output (STEP geometry,
   gate.py/accept.py JSON results, connections/joint registries, part_connectivity output). If the user's
   request doesn't make this clear and the working directory has both kinds of artifacts, ask which one (or
   "both" — see step 2c).
2. **Scope the target.**
   - **2a — codebase:** read the repo's map (AGENTS.md/README/dir tree) for context. Note roughly how much
     source is in scope. If it's large (rough guide: more than what one agent can read in full — say >2500
     lines of files that actually matter), do NOT bucket/panel it — instead tell the single agent to
     prioritize highest-risk areas (entry points, shared state, anything safety- or money-adjacent, code the
     repo map flags as load-bearing) and to say explicitly in its output what it could and couldn't fully
     cover. Don't silently claim full coverage of something it skimmed. Also resolve, for the Apply-mode fix
     phase, how to run the target's real test/build suite (the command, not a guess) — the same resolution
     `/probe`/`/spar` require of their TARGET.
   - **2b — CAD/model output:** point the agent at the gate/accept output JSON, the connections/joint
     registry, and the actual geometry artifacts (STEP/GLB) — not just declared pass/fail flags. Physical
     claims must be checked against the real constraint, never a bbox/registry/declared-type proxy (e.g. a
     bolt only counts if it clamps two solids at true zero-gap min-distance, not "a fastener object exists
     near this location"). Flag stale numbers and any "PASS" that doesn't actually test the thing it claims
     to test.
   - **2c — both:** run step 3 twice (once per target type, own prompt variant below), as two separate agent
     dispatches — still one agent per target, not a panel.
3a. **Dispatch the raw finder Agent** — general-purpose subagent type; effectively Read/Grep/Glob/Bash-read-only
   — no Edit/Write, no mutating scripts, with the raw find prompt below for the relevant target type, unmodified.
   **The finder is READ-ONLY in BOTH modes**, including Apply: it is still enumerating issues in the target's
   CURRENT state, and editing mid-enumeration would change that state out from under itself. Fixing is a
   separate, later phase (Step 7) with its own dedicated agent. Keep the find step raw and uncapped — per
   `panel-ultra-review`'s own finding, adding structure (a rubric, a top-N cap, a review checklist) at the find
   step trims the long tail of real issues. Structure belongs only around the finder (this procedure), never
   inside its prompt. (For the standards axis, the Fowler smell taxonomy in `~/.claude/reference/refactoring.mini.md`
   is a sourced baseline the finder can sweep against — a versioned list instead of one recalled from memory.)
3b. **Dispatch a second Agent running the built-in `code-review` skill** (added 2026-07-08, Douglas's explicit
   request) — a distinct, purpose-built lens different in kind from the raw finder's open-ended prompt, run in
   BOTH modes since `code-review` is read-only by design (mirrors `/spar`'s own precedent for composing
   `security-review`: a purpose-built skill catches known-shape issues a general prompt might phrase
   differently or skip, rather than relying on the raw finder to stumble into them). Dispatch prompt: "Invoke
   the 'code-review' Skill against <TARGET SCOPE> and report its findings. Use the Skill tool exactly as
   you normally would; do not substitute your own ad-hoc review for it." Translate its output into the same
   ID/SEVERITY/WHERE/ISSUE/WHY/FIX shape as the raw finder's blocks (tag each with SOURCE: code-review) and
   fold the results into the same pool feeding Step 5 and Step 6 — one findings report, not two. (3a + 3b
   together are the **standards axis**; the spec axis in 3c stays a separate pool.)
3c. **Dispatch a Spec-axis finder** — the second review AXIS (added 2026-07, from Matt Pocock's `code-review`
   two-axis split). Steps 3a/3b review the *standards/quality* axis (is the code correct and clean); this agent
   reviews the *spec* axis: does the target actually do what its **originating intent** — the issue/PRD/task/
   `CURRENT-TASK.md` it claims to satisfy — asked for. It looks ONLY for: (a) a stated requirement not
   implemented or only partially done, (b) behavior implemented but contradicting or misreading the intent,
   (c) scope creep — changes the intent never asked for. It needs that originating intent as input; if there is
   no spec/issue/task to review against (a cold codebase with no stated intent), say so and SKIP this axis
   rather than inventing acceptance criteria. Read-only, both modes. Tag findings `SOURCE: spec-axis` and keep
   them in a SEPARATE pool from the standards-axis findings — the two axes are never merged (see Step 6).
4. **Read-only enforcement for the raw finder**, stated explicitly in its dispatch prompt (not assumed): "Do
   NOT edit, write, move, or delete any file. Do NOT run any script that mutates state — no gate/accept/rebuild
   runs that regenerate artifacts. Reading their existing output is fine; re-running them is not." This
   applies to the raw finder regardless of mode. The `code-review` skill (Step 3b) needs no equivalent
   instruction — it has no write/edit capability of its own to constrain.
5. **Self-check — refutation plus runtime ground truth via the built-in `verify` skill** (added 2026-07-08,
   Douglas's explicit request for the `verify` half). Skip for a fast pass; include when the user wants extra
   confidence, and default it ON when in Apply mode with more than a couple findings, since a fixer would
   otherwise burn real edits on a false positive. Two parts, run in BOTH modes:
   - **Refutation.** Dispatch a small agent whose only job is to try to REFUTE the finders' top findings
     against the real code/data, defaulting to "refuted" if it can't confirm.
   - **Ground truth.** For any finding that makes a runtime claim (an endpoint returns X, a gate reports PASS,
     a UI renders Y) where the target has an actual runnable surface, dispatch the built-in `verify` skill
     against that surface and use its PASS/FAIL/BLOCKED/SKIP verdict as real evidence instead of a re-read of
     the code — the same discipline `panel-ultra-review`'s CAD clause already applies to bbox/registry
     proxies, extended to solo-review's own self-check. Skip this half with a one-line note if the target has
     no runnable surface (pure library/data code with no entry point) — don't force a `verify` pass on
     something that can't be exercised.
   Drop anything refuted, and downgrade anything `verify` reports FAIL/BLOCKED against the finding's own
   claim, before either the report (read-only) or the fix phase (apply) sees it.
6. **Write the findings report.** `<target>/SOLO_REVIEW_<YYYY-MM-DD>.md`, grouped FIRST by review axis — a **Standards/quality** section (findings from 3a + 3b) and a **Spec** section
   (findings from 3c), reported SEPARATELY and never merged or reranked across each other (Matt Pocock's
   code-review rule: keeping them apart stops a loud convention nit from masking a quiet missing-requirement, or
   vice-versa) — then by severity
   (critical/high/medium/low) within each axis, each issue with WHAT / WHERE (`file:line` or the specific model artifact) / WHY
   it matters / FIX (concrete) / SOURCE (raw-finder or code-review, plus the `verify` verdict where Step 5
   produced one), with a one-line TL;DR at the top. If the report is long, have the agent write
   it incrementally — `Write` the header/first section, then append small chunks via `Bash`
   (`open(path,"a").write(chunk)`), each well under ~2000 characters — rather than one giant `Write` call.
   `panel-ultra-review`'s "Large-output subagent stalls" note applies here too: a single continuous generation
   over ~150+ findings reliably triggers a mid-stream stall. **This step happens in BOTH modes** — it's the
   one artifact both end up on; Apply extends it with a Disposition section in Step 9.

### Apply mode (default) — Steps 7-10

7. **Dispatch a SECOND Agent (the fixer)** — general-purpose, this time WITH Edit/Write/Bash access — with:
   - the full findings report (verbatim, every surviving ID/SEVERITY/WHERE/ISSUE/WHY/FIX block, minus anything
     Step 5 refuted)
   - TARGET, plus how to run its real existing test/build/gate suite (resolved in Step 2a/2b)
   - instructions: root-cause each finding first — don't patch a symptom. Where the target has a real test
     harness, reproduce the finding with a FAILING test BEFORE changing implementation code (RED), then make
     the minimal change that makes it pass (GREEN). Where there's no test harness for that specific finding,
     make the fix and verify it by direct re-execution / a live re-check instead. Either way, re-run the
     target's FULL existing test/self-test suite afterward to confirm no regression, and where the target has
     a runtime/app surface (GUI/CLI/service), also re-run the built-in `verify` skill against it (added
     2026-07-08, Douglas's explicit request) — PASS/FAIL/BLOCKED/SKIP on the actual behavior each fix claims
     to have restored, not just a green test suite. Make ONLY the change each finding requires — no unrelated
     refactors, no drive-by cleanup, no speculative abstractions.
   - **CAD/gate safety clause (non-negotiable):** a CAD/model finding must be fixed by correcting the actual
     defect — the code, the connections/registry logic, the geometry-generation step — **never** by loosening
     a threshold, weakening a check, or otherwise making a gate/accept script easier to pass. If the only
     available "fix" would do that, mark it `wont_fix` with that reason instead of applying it. This mirrors
     Douglas's standing rule that a gate threshold is never loosened to manufacture a pass.
   - if the target keeps a tracked mirror elsewhere in this repo's convention (e.g. this harness's `~/.claude`
     ↔ `claude-global-config` split), keep the mirror in sync as part of the fix.
   - **No commits.** Applying means editing and verifying, never `git commit`/`git push`, unless Douglas
     separately asked for that.
   - if fixing a finding would itself require bypassing a safety mechanism, or it genuinely needs Douglas's
     judgment call (a tradeoff, an ambiguous spec, a destructive/hard-to-reverse change), mark it `skipped` or
     `wont_fix` with a clear reason — do not force a workaround.
   - report, per finding id: status (`fixed`/`skipped`/`wont_fix`), evidence (the failing-then-passing test
     output, or a live re-check), and for anything not fixed, why.
8. **Dispatch a THIRD Agent running the built-in `simplify` skill — Apply mode ONLY** (added 2026-07-08,
   Douglas's explicit request; never runs in read-only mode — see the mode note above, since it mutates code
   and read-only mode's whole contract forbids that). Scope it strictly to the files Step 7's fixer just
   touched, not the whole target, matching this procedure's own "only the change each finding requires"
   discipline extended to `simplify`'s own diff. Dispatch only after Step 7's `verify` re-check passes, so
   `simplify` works from a known-good state. Dispatch prompt: "Invoke the 'simplify' Skill against <files
   the fixer touched> and report what it changed." After it runs, re-run the same regression check from
   Step 7 (test suite, plus `verify` where applicable) once more — `simplify`'s own changes are not exempt
   from the same no-regression bar the fixer is held to. If `simplify` finds nothing to simplify, say so
   plainly rather than reporting an empty diff as a finding.
9. **Append a Disposition section** to `SOLO_REVIEW_<YYYY-MM-DD>.md`: a table of id → severity → status
   (fixed/skipped/wont_fix) → one-line reason/evidence, plus the final test-suite result (pass count) and,
   where applicable, the final `verify` verdict. Every finding from Step 6 appears here — never let one
   silently disappear between the report and the disposition, including anything sourced from Step 3b's
   `code-review` pass. Add a separate line (not a finding id) for Step 8's `simplify` diff: files touched and
   what changed, or "nothing to simplify" if it found none.
10. **Final report to Douglas:** total found → total fixed → what's skipped/`wont_fix` and why → confirmation
   the target's test suite (and, for a frontend target, its own browser/Playwright check if one exists) still
   passes after the fixes → what `simplify` changed, if anything → full absolute path(s) of everything
   changed, per the standing Files-list convention.

### Read-only mode

Stops after Step 6 — the ORIGINAL solo-review behavior. Report the findings (grouped by severity, one-line
TL;DR) and the file path. Do not touch the target repo's own CURRENT-TASK/WORK_QUEUE/STATUS files — this is a
read-only side artifact, not a task-tracking entry. Nothing is edited; Douglas decides what to do with each
finding. Steps 3b (`code-review`) and 5's `verify` ground-truth half still ran before this point — both are
read-only by design, so they fit this mode's own contract. Step 8's `simplify` never runs here.

## Raw find prompt — codebase variant

```
You are a rigorous, skeptical senior engineer doing an EXHAUSTIVE, open-ended code + design review of the
codebase below. Read the source and search it however you see fit. Find AS MANY distinct, real issues as you
can, of ANY kind: correctness bugs, logic errors, off-by-one, wrong math/units/signs; silent failures (bare
except, swallowed errors, default-on-missing that hides a problem); validation/gate BLIND SPOTS (a check that
can be fooled or doesn't test what it claims); stale-data / ordering / race hazards; unsafe exec/injection;
places where code does NOT do what its docstring/name claims; producer/consumer contract mismatches; dead/
unreachable code; fragile assumptions. Do NOT stop at a fixed number and do NOT cap your length. Completeness
beats brevity. Do NOT edit, write, move, or delete any file, and do NOT run any script that mutates state
(no test/gate/accept/rebuild runs that regenerate artifacts) — reading existing output files is fine.

REPO CONTEXT: <one paragraph: what this codebase is, its pipeline stages/subsystems, and anything it's known
to already have issues with, so the agent looks for NEW ones beyond those>

TARGET SCOPE: <path(s) / package(s) to review, or "the whole repo, prioritizing highest-risk areas" if large>

For EACH issue output a block exactly:
ID: <short-slug>
SEVERITY: critical|high|medium|low
WHERE: <file>:<line-or-function>
ISSUE: <what is wrong>
WHY: <why it matters>
FIX: <a concrete fix>

Then finish with TOP: (the single most important fix) and CHECK: (what you'd verify that you couldn't from
the code alone). No preamble; start with the first issue.
```

## Raw find prompt — CAD/structural model variant

```
You are a rigorous, skeptical mechanical/structural reviewer doing an EXHAUSTIVE, open-ended review of the CAD
model output below. Your job is to catch a "PASS" that doesn't actually prove what it claims. Read the gate/
accept output, the connections/joint registry, and the actual geometry artifacts (STEP/GLB) yourself — do not
trust a summary number without opening the underlying data. Find AS MANY distinct, real issues as you can:
any check that uses a proxy (bounding box, declared part type, registry entry) instead of the true physical
constraint it claims to verify (e.g. true min-distance / point-in-solid for a clamped bolt, not "an object
exists near this location"); any two signals in the pipeline that both claim to be authoritative and disagree
(e.g. gate.passed=false but accept.passed=true on the same build); stale numbers left over from a prior run;
connections with no realized physical means (declared "connected" but nothing actually joins the two solids);
loosened thresholds; floating/non-mating parts credited as connected; units or sign errors in dimensions.
Do NOT stop at a fixed number and do NOT cap your length. Completeness beats brevity. Do NOT edit, write, move,
or delete any file, and do NOT re-run any gate/accept/rebuild script that regenerates artifacts — reading their
existing output is fine.

MODEL CONTEXT: <one paragraph: what this assembly/model is, what the gate/accept scripts claim to verify, and
the current honest pass count if known, so the agent looks for NEW issues beyond what's already tracked>

TARGET SCOPE: <path(s) to the gate/accept JSON, connections registry, and geometry files to review>

For EACH issue output a block exactly:
ID: <short-slug>
SEVERITY: critical|high|medium|low
WHERE: <file/artifact + the specific joint, part, or check it concerns>
ISSUE: <what is wrong>
WHY: <why it matters — what would actually fail physically if this shipped>
FIX: <a concrete fix>

Then finish with TOP: (the single most important fix) and CHECK: (what you'd verify that you couldn't from
the data alone). No preamble; start with the first issue.
```

## Safety constraints for Apply mode (every run, no exceptions — mirrors `/spar`)

- **Never dispatch the finder or the fixer with elevated/bypass permissions.** Run both at default tool
  permissions.
- **If the target's own safety layer (or the classifier) blocks an action mid-fix, that is a correct block,
  not a bug** — do not route around it. Mark that finding `wont_fix` with the block as the reason.
- **Stay scoped to the target itself.** No killing/touching unrelated processes, files, or services.
- **Make only the change each finding requires** — no unrelated refactors, no drive-by cleanup, no
  speculative abstractions beyond the fix.
- **No commits.** Fixing means editing and verifying, never `git commit`/`git push`, unless Douglas
  separately asked for that.
- **The CAD/gate clause above is absolute**: never loosen a threshold or weaken a check to force a pass.
- **If the target keeps a tracked mirror elsewhere in this repo's convention**, the fixer keeps the mirror in
  sync as part of the fix.
- **Applies equally to the composed `code-review`, `verify`, and `simplify` dispatches** (Steps 3b, 5, 8) —
  same default permissions, same scope discipline, same no-commit rule. None of the three gets an exception.

## Output

**Apply mode:** `SOLO_REVIEW_<YYYY-MM-DD>.md` with a Findings section (Step 6) followed by a Disposition
section (Step 9) appended after the fix phase — one file, the full before/after story.
**Read-only mode:** `SOLO_REVIEW_<YYYY-MM-DD>.md` with just the Findings section, as before.

---

*Tracked copy: also save this file to `claude-global-config/commands/solo-review.md` (per the skills-are-tracked
convention) after a NASA scrub.*
