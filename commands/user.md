---
name: user
description: "Full-claimed-functionality proof loop: hand the running app to a fresh, INDEPENDENT cross-family agent (default GPT-5.5 via the NASA GEN/NMC proxy) that gets only what a real user gets — the app plus its claimed-functionality doc, zero access to source/commit history/intent — and have it exercise EVERY claimed feature across three surfaces (a CLI, an MCP server, and the real GUI via Playwright). Build/verify the CLI + MCP surfaces first (invoking /make-cli and /make-mcp), derive tasks two-step from the CLAIM (Gherkin scenarios -> per-surface executable tasks), fill a Kitchen-Loop coverage matrix (claimed-feature rows x CLI/MCP/GUI columns), and loop fix-and-retry — with a freshly re-derived tester task each retry so the fixer can't overfit a fixed probe set, a state-hygiene schedule (read-only cells parallel, state-mutating cells serial with baseline resets), a pass^k confirmation re-run so a lucky single green cannot read as proven, and a mandatory regression-injection self-check that the eval's verdict actually flips under deliberate damage — until every cell is proven or blocked or the max-iteration/budget cap hits. Report the matrix honestly: proven (with which assertion tier proved it) / failed / flaky / blocked-ambiguous / N-A, never silently omitted, never 'fully tested'. Use when Douglas says 'prove the app works', 'have an agent test everything', 'acceptance-test the whole app', 'does the app actually do what it claims', 'run the user skill', '/user'."
---

# /user [target] [--claims <path/url to the claimed-functionality doc>] [--tester-model <name>] [--max-iterations N] [--budget "<turn/cost ceiling>"]

Proof of an app is a claim only an outsider can make for it. A test the author's own
agent passes proves the design the author already had in mind: the agent and the code share a mental model, so
a green result means the two agree. Whether the app does what it promised a real user is the separate question
this command answers, by handing the running app
to a fresh, independent agent that gets exactly what a real user gets: the app and its claimed-functionality
doc, and nothing else — no source, no commit history, no statement of intent. It cannot satisfy a check by
reading the implementation, because it never sees the implementation. It exercises every claimed feature, every
way the app can be driven — a CLI, an MCP server, and the real GUI — and what a stranger can actually complete
end-to-end is what gets reported as proven. The name is the stance: a real **user**, doing everything the app
promises, on every surface that offers it.

## What this is NOT

- **Not `/spar`.** `/spar` is a hostile insider that attacks a target's internals to find breakage, with a
  fresh adversary each round. `/user` is a naive outsider that proves the app does what it CLAIMS, from a real
  user's stance, across every surface. `/spar` hunts for what breaks; `/user` establishes what the claimed
  functionality can be shown to actually do. If Douglas wants adversarial break-fix on the internals, point him
  at `/spar`.
- **Not `/probe`.** `/probe` measures the QUALITY of the code's own test suite — property sweeps, a mutation
  score, coverage gaps — by interrogating the tests. `/user` never touches the test suite; it drives the
  RUNNING app end-to-end through its real interfaces. A weak test suite is `/probe`'s business; an unproven
  claimed feature is `/user`'s.
- **Not `/verify` or `verification-before-completion`.** Those drive ONE flow once to confirm a single change
  landed. `/user` proves ALL claimed functionality across CLI + MCP + GUI, looping fix-and-retry until every
  cell is proven or blocked.
- **Not `/panel-ultra-review`.** That is static, read-only, multi-model code review — it reasons about code
  without running it. `/user` is dynamic: it runs the app and asserts real resulting state.
- **Not `/make-cli` / `/make-mcp`.** `/user` USES those as its Phase 1 — it invokes them to give the app the CLI
  and MCP surfaces it will then test. Building the surface is a means; proving the claim across it is the point.

## Procedure

### Step 0 — Resolve TARGET and the claimed-functionality doc from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone: what the app is, where it lives
(path), how to run it (the real start command / port / URL), and — separately — the SOURCE of its CLAIMED
functionality (a README, a spec, `--help` output, or an explicit functionality list, via `--claims <path/url>`).
The claimed-functionality doc is load-bearing: it is the ONLY thing the independent tester is allowed to know
about what the app should do, so it must be a real, self-contained statement of the claims, not a pointer into
the source. If ARGUMENTS lacks the run command or the claims source and neither is obvious from the
conversation, ask for both before proceeding — do not guess at a runnable app or infer claims from the code
(inferring claims from the implementation is exactly the leak this command exists to prevent). **If the target
has a `SPEC.md` produced by `/spec`, its `§Acceptance` block is the canonical claims oracle** — pass
`--claims SPEC.md`. Its criteria are already Given/When/Then with stable `AC-###` IDs and graders, so Step 3
can consume them directly and skip re-deriving scenarios (cite the `AC-###` in each verdict). Parse
`--max-iterations N` (default **8**) and an optional `--budget` (a total turn/cost ceiling; it is a stop
condition, not a promise). Confirm the app actually runs before spending anything downstream.

### Step 1 — GATE: preconditions + surface selection (mandatory, BEFORE any building or testing)

This gate mirrors `/hone`'s and `/probe`'s gate — check the conditions that make the whole pass meaningless or
fake BEFORE spending time on them.

1. **Is there a real claimed-functionality doc?** If there is no explicit statement of what the app claims to
   do, there is nothing to prove against — a tester with only the app and no claims would be inventing its own
   acceptance criteria, which is the leak in another form. Say so plainly and STOP; ask Douglas for the claims
   source rather than manufacturing one.
2. **Are the claims concrete enough to test?** A claim like "supports advanced search" or "handles large files
   gracefully" has no observable pass/fail without a human deciding what it means. For any such claim, mark it
   **ambiguous, needs a human call** in the matrix rather than letting the tester guess an interpretation and
   grade itself against its own guess. Report the ambiguous claims explicitly; concrete claims proceed.
3. **Which of the three surfaces genuinely apply?** A headless service may legitimately have no GUI; a
   GUI-only app may have no CLI yet (Phase 1 can add one) but also may have no meaningful CLI surface at all.
   Decide per surface whether it applies. Do NOT manufacture a surface that does not apply — mark it **N/A** in
   the matrix with the reason, the same way `/hone` defers a frontend target rather than forcing a profile.

If the gate fires on condition 1, that is the finding — report it and stop. Conditions 2 and 3 shape the matrix
(ambiguous rows flagged, inapplicable columns N/A'd) rather than stopping the run.

### Step 2 — Phase 1: build/verify the CLI + MCP surfaces

For each applicable surface the app lacks, give it one — invoke **`/make-cli`** to add a CLI and **`/make-mcp`**
to add an MCP server. Then smoke-test both LIVE, never by reading the generated code: actually invoke the CLI
and observe structured output, and actually connect to the MCP server over its real transport and complete a
full `initialize` handshake. A surface that was "built" but does not respond live is not a surface yet — report
that and treat it as blocking for its column. A surface the app already has is verified the same way (live), not
assumed to work because it exists.

### Step 3 — Phase 2: derive tasks two-step, traceable to the CLAIM (build the matrix up front)

Derivation must trace to the claim, never to the implementation, or the whole independence guarantee is gone.
Two steps:

1. **Generate natural-language, Gherkin-style scenarios purely from the claimed-functionality doc** — one or
   more `Given/When/Then` scenarios per claimed feature, written from a user's stance, referencing only what the
   doc promises. Nothing here may reference an internal function, a code path, or a commit; if a scenario can
   only be written by looking at the source, that claim is under-specified — kick it back to the Step-1
   ambiguous bucket.
2. **Compile each scenario into a per-surface executable task** — a concrete thing to do on the CLI, the MCP
   server, and the GUI, each with the assertion that would prove the `Then` clause, and each classified
   **read-only or state-mutating** (does executing it change the app's persistent state?). The classification
   drives test scheduling and reset hygiene in Step 4.

Build the **Kitchen-Loop coverage MATRIX** up front: rows = claimed features, columns = CLI / MCP / GUI. Every
cell starts **empty** — an empty cell is a claim to be proven, not an assumption of success. Inapplicable cells
are N/A (per the gate); ambiguous rows are flagged. This matrix is the spine of the run and the shape of the
final report.

### Step 4 — Phase 3: the fresh independent tester exercises every cell

Spawn the tester as a genuinely separate agent whose model follows ONE rule: **a capable frontier model of a
DIFFERENT family than the builder/fixer.** The fix loop runs on Opus/Claude, so the tester must not be Claude —
a same-family tester shares the builder's blind spots and quietly defeats the independence this whole command
rests on. The **default is GPT-5.5 via the NASA GEN/NMC proxy** (the OpenAI-compatible Codex/NMC endpoint per
Douglas's DELEGATE policy and the NMC-Hub endpoint memory; the codex-brief route) — frontier-capable so a
failure means the app rather than a weak tester, cross-family from the Claude fixer, and cheap via GEN.
Override with `--tester-model <name>` only within that rule: a cheaper cross-family model suits simple surfaces;
the builder's own family is never a valid tester. It gets **only** what a real user gets: the running app, the
claimed-functionality doc, and the CLI/MCP/GUI interface descriptions. It gets **zero** access to source,
commit history, or any statement of the builder's intent. This is the structural skepticism the whole command
rests on — an agent that has read the implementation cannot un-read it and will satisfy whatever check the code
makes visible, so the tester must never see the code.

**Mechanical reality of the cross-family default (learned 2026-07-18).** On this machine the Agent tool cannot
route a subagent's model to GPT-5.5-via-GEN: the GEN/NMC proxy is a text-completion endpoint with **no tools**,
so a GEN model literally cannot drive Playwright or an MCP client. Routing the tester through
`agent(model:'gpt-5.5-gen')` either errors or silently falls back to Claude — a same-family tester wearing a
cross-family label, which is the exact leak this command exists to prevent. Honor the cross-family rule by a
mechanism that actually works: (a) install `@playwright/mcp` (it is installed + registered on this machine now)
and let a genuine browser-driving agent use it; (b) drive the headless surfaces (MCP stdio, HTTP API) from the
**codex CLI** (`C:/Users/dmcgowa2/tools/nodejs/codex`) or the `codex-gen` MCP, which IS cross-family; (c) if none
is reachable, fall back to a **source-blind Claude subagent** — it never reads the implementation, so it shares
the fixer's model-family blind spots but not the code's, which is weaker than cross-family and must be
**disclosed as a caveat in the matrix**, never presented as the gold-standard proof. Faking cross-family by
running a same-family tester and reporting it as independent is forbidden.

The tester attempts the tasks in **batches** — with **state hygiene** deciding what may run in parallel.
Cross-cell state pollution is a documented false-verdict source in exactly this kind of harness (WebArena /
BrowserGym: stale cookies and sessions between episodes, one task's writes corrupting the next task's reads —
their fix is a backend reset between episodes). So: **read-only cells may run in parallel; state-mutating cells
run one at a time against the instance**, each GUI cell gets a fresh browser session/profile, and app state is
reset to a known baseline between iterations (restart the instance or restore the baseline data) so iteration
N's leftovers can't decide iteration N+1's verdicts. On each applicable surface:

- **CLI-driving.** Demand structured, machine-parseable success output — the CLI must state exactly what
  changed, not just exit 0 in silence (exit 0 plus silence is not proof to an agent). Where the CLI has no
  structured output, the harness runs an INDEPENDENT verification command/query after each action rather than
  trusting stdout. Use differentiated exit codes to decide retry vs abort vs escalate.
- **MCP-driving.** Connect over the real transport (stdio/SSE/HTTP) with a full `initialize` handshake, never
  in-process — wire-level bugs a unit test misses are exactly what a real user hits. MCP has no protocol-level
  session, so explicitly track any state HANDLE a creation-tool returns and pass it on the follow-up calls that
  need it. Assert the actual resulting STATE via a read-tool or a side-channel, not merely that the write-tool
  returned success — "responds" is weaker than "responds correctly."
- **GUI-driving.** Use `@playwright/mcp` (install `npx @playwright/mcp@latest`; verify the exact current
  version by direct fetch of `github.com/microsoft/playwright-mcp` rather than hardcoding a version — the
  digest saw ~v0.0.78 but flags it unconfirmed) — its accessibility-tree `browser_snapshot`/`browser_find` and
  the `browser_verify_*` assertion family give deterministic non-visual checks instead of screenshot diffing.
  Fall back to a programmatic state check (query the app's real DOM/backend state) when it is queryable; fall
  back to an LLM-judge ONLY when no ground truth is queryable. Log which mode decided each verdict.
  A tier-3 judge verdict must come from a **structured evidence bundle + per-criterion rubric** — a holistic
  "did it work?" over one screenshot is a known weak grader. Give the judge the task goal, the full action
  sequence with URLs,
  the final accessibility tree, and the first + last screenshots, and have it grade each `Then` clause as its
  own criterion (AgentRewardBench's judge-input design). Known judge failure modes to design against:
  trajectory-length bias (longer looks better), position bias and agreeableness/sycophancy bias (swapping two
  identical answers flips ~40% of verdicts, and a judge over-accepts an agent's confident assertion — 2026
  LLM-judge audits; From Confident Closing to Silent Failure), and blindness to wrong tool arguments and to tool
  calls that were never defined (BabelJudge) — the rubric names the specific state the claim requires so the
  judge can't wave a busy trajectory through.
- **Success assertion — three tiers, cheapest/most-reliable first.** (1) programmatic state/DB/API check;
  (2) structured tool-verify (`browser_verify_*`, MCP state-read); (3) LLM-judge as a last resort. Record which
  tier produced each verdict. An LLM-judge tops out around ~80% agreement with ground truth (AgentRewardBench),
  so a judge-only verdict is never allowed to silently count as equivalent to a programmatic proof — it is
  marked as tier-3 and carries disclosed uncertainty into the report.

**Discovery mode — agent-usability, distinct from claim-verification (added 2026-07-18, Douglas's request).**
The claim-by-claim tasks prove the app *does what it says*; they do not prove an agent (or a first-time human)
can *figure out how to drive it* without being told. Run at least one pass where the tester gets ONLY the
running app plus bare connection facts — the URL, how to launch the MCP server, that an HTTP API exists — and
NO step-by-step, NO feature list, NO how-to. Then measure whether it can work out what the app is for and drive
it end to end on its own, through the UI and headlessly. What it can and cannot discover unaided is the
agent-UX signal, separate from correctness: a claimed feature that works but no agent can find is a real gap for
an agent-driveable tool (this is how the run-inventory legibility problem and the hidden query box surfaced).
Report the friction points — where the tester hesitated, guessed wrong, or gave up — not just pass/fail.

**Confirmation re-run — one green is a sample, and pass^k says a single sample flatters (added 2026-07-21).**
Under the current loop shape a cell that passes on its first attempt is never exercised again, so the flaky
bucket can only ever catch cells that FAILED first — flakiness hiding behind a lucky first pass is invisible.
The field's numbers say that hidden gap is large: τ-bench's pass^k metric (all k trials must succeed) shows
agents at roughly 61% pass@1 dropping to roughly 25% pass^8 on the same tasks; CORE-Bench sees the same
collapse. So before the final report, every cell marked proven gets **one confirmation re-run with freshly
re-derived task wording** (after the between-iteration state reset). Both pass → **proven (×2)**. The re-run
fails or diverges → the cell is reported **flaky** in the final matrix (the loop has ended; it needs a human
call or a next run rather than a silent green). If budget
forces rationing, confirm the state-mutating and tier-3 cells first and report any unconfirmed proven cell
explicitly as **proven (×1, unconfirmed)** — the run count is part of the verdict.

### Step 5 — Phase 4: fix-retry loop with real loop control

Any cell that does not come back proven enters the fix loop. Diagnose and fix the **APP** (Superpowers
`systematic-debugging` + TDD: root-cause first, RED failing test before the implementation change, GREEN minimal
change), then re-run that cell with a **freshly re-derived tester task wording** so the fixer cannot overfit to
a fixed probe set. The fixer never sees or edits the acceptance checks — the oracle is hidden from whoever
produces the fix, so the fix has to make the claimed behavior real rather than make the check pass.

**Triage every failing cell against source-of-truth BEFORE fixing it (added 2026-07-18; three-way 2026-07-21).**
Read the tester's transcript/evidence first — Anthropic's eval guidance says the transcript is what tells you
whether the agent made a genuine mistake or the grader rejected a valid solution. A failing cell is one of
three things, and only one of them gets a fix:
1. **App bug** → enters the fix loop.
2. **Intended control read as a bug.** A source-blind tester reports deliberate controls as broken — a CUI
   local-only exclusion, a rate limit, an intentional 403. If the behavior is intended, the cell is
   **N/A-by-design**: correct the matrix and fix only the *legibility* (an honest error message, a
   `local_only` marker, a UI note), never the control itself. Tearing out a security control to turn a
   tester's cell green is the worst thing this loop can produce — this pass a run-search "bug" was a
   deliberate CUI-egress guard, and blindly "fixing" it would have exposed NASA-internal content to a cloud
   client.
3. **Tester error** — the transcript shows a wrong command, a misread output, or giving up early on a working
   feature. No app change: re-run the cell with a corrected interface description (and note the friction as an
   agent-UX signal for discovery mode). Dispatching a fixer against a tester's own mistake burns iterations and
   risks "fixing" working code.

Loop control is defined BEFORE the loop runs, not improvised inside it:

- **Hard max-iteration cap** (`--max-iterations`, default 8) and a **budget** ceiling — either one hit is a stop
  condition, and the matrix reports where it stopped.
- **Per-cell retry cap of 2–3.** A cell that fails past its cap is marked failed or blocked, not retried
  forever.
- **Transient/flaky vs systemic.** Repeated IDENTICAL failures (wrong env, bad credential, genuinely broken
  logic) fail fast and escalate rather than retry blindly. Inconsistent results across retries are a distinct
  outcome — marked **flaky (retried N, inconsistent)**, separate from failed and from blocked.
- **Loop/duplicate detection.** If consecutive fix attempts are near-identical, abort that cell and mark it
  **blocked** rather than spinning.

Matrix cell states are distinct and never collapsed: **proven** / **failed** / **flaky** / **blocked-ambiguous**
/ **N/A**.

### Step 6 — Phase 5: keep the eval HONEST (mandatory, not optional)

An eval whose score does not move when the target is deliberately damaged is a fake eval — it is measuring
nothing. Periodically inject a deliberate regression (disable a known-good feature, corrupt an MCP tool's
output) and confirm the tester's verdict for that cell FLIPS to fail. If the verdict does NOT flip under
injected damage, the harness is proving nothing and every green it produced is suspect — fix the harness before
trusting any result. This is Douglas's falsification rule made into a mechanism, and it runs; it is not a
disclaimer. Restore the injected regression immediately after the check and confirm restoration.

### Step 7 — The honest final report

The Kitchen-Loop coverage matrix IS the report. Every claimed-feature × surface cell is marked, none silently
omitted:

- **proven** — with WHICH assertion tier proved it (tier 1 programmatic / tier 2 structured tool-verify / tier 3
  LLM-judge) and the run count (**×2 confirmed** via the pass^k re-run, or **×1 unconfirmed** if budget cut the
  confirmation — the count is part of the verdict). A tier-3 proof carries disclosed uncertainty; it does not
  read as equal to a tier-1 proof.
- **failed** — with the diagnosis and what remains.
- **flaky** — retried N times, inconsistent results; named as its own bucket, never laundered into proven or
  failed.
- **blocked-ambiguous** — the claim was too vague to test, or the loop aborted on duplicate fix attempts; this
  needs Douglas's call.
- **N/A** — the surface does not apply, with the reason.

Also report:

- **Which cells carry irreducible LLM-judge uncertainty**, stated plainly — some GUI cells with no queryable
  ground truth can only reach a tier-3 verdict, and the report says so rather than presenting them as certain.
- **The honesty self-check result** — that the eval's verdict was confirmed to flip under injected regression
  this pass (and if it did not, that finding dominates the report).
- **Never "fully tested" or "100% verified."** Mirror `/spar`'s "no new issues across the last 2 rounds",
  `/hone`'s "no change beat the baseline past noise", and `/probe`'s refusal of "fully tested." The honest
  statement is: *"every concrete claimed feature was exercised on surfaces X and proven at tier Y over N
  iterations; these cells remain failed/flaky/blocked/ambiguous and need a human call; these carry tier-3 judge
  uncertainty."*
- Full absolute path(s) of anything changed, per the standing Files-list convention. Confirm every worktree was
  removed and the main tree's `git status` is clean.

## Safety constraints (apply every phase, no exceptions)

- **Never run with elevated/bypass permissions.** A generic "prove the app works" ask does not justify
  disabling the permission system; run at default tool permissions. If a safety layer or the classifier blocks
  an action mid-run, that is a correct block — narrow scope and try a different angle, do not route around it.
- **The fix loop runs in an isolated git worktree; never touch the caller's main tree — and PROVE isolation is
  possible before claiming it.** `git worktree add` only carries COMMITTED content; an untracked target does not
  exist in a fresh worktree at all. Before the first fix, confirm the target is inside a git working tree, its
  own content is tracked, and actually create-and-remove a scratch worktree to prove the target's files are
  present in it (the same check `/probe` and `/hone` run). If isolation can't be proven, STOP and ask Douglas
  (commit the target first — recommended — or proceed unisolated, in which case fixes touch the real tree and
  the report must say so plainly) rather than silently editing the main tree while claiming isolation.
- **Clean up when done.** Remove every worktree (`git worktree remove --force`) and prune, restore any injected
  regression from the honesty self-check, and confirm `git status` on the main tree shows nothing unexpected.
  **Delete a throwaway branch with `git branch -d` (safe delete), not `-D`** — this machine's
  `block-dangerous-bash.js` hook unconditionally blocks `git branch -D`. Run worktree-remove and branch-delete
  as two separate calls, never chained. If a branch genuinely can't be `-d`-deleted, leave it and note the
  dangling pointer in the report rather than routing around the block.
- **The GEN / GPT-5.5 key is read from the environment ONLY.** Never print it, never write it to a file, never
  echo it into a log or a prompt. If the environment variable the NMC/GEN proxy needs is missing, STOP and say
  so — do not hardcode a fallback key.
- **Playwright drives a LOCAL instance of the app.** No driving a shared/production deployment; stand up and
  tear down a local instance for the GUI surface, and stay scoped to it.
- **The fixer makes only the change each failing cell requires** — no unrelated refactors, no drive-by cleanup,
  no speculative abstractions. If a cell can't be fixed safely in scope, or the claim is genuinely ambiguous,
  it is marked blocked-ambiguous with a reason instead of forced through.
- **No commits.** Proving means building the surfaces, driving the app, fixing failing cells in a worktree, and
  reporting — never `git commit` / `git push`, unless Douglas separately asked for that.
- **If the target keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's `~/.claude`
  ↔ `claude-global-config` split), note it and keep the fix in sync as part of that cell's fix, per the standing
  convention.

## Procedure (how to run it)

1. Resolve TARGET, the claims source, `--max-iterations`, and `--budget` per Step 0.
2. **Run the GATE (Step 1) yourself first, before the Workflow.** Confirming a real claims doc exists, flagging
   ambiguous claims, and selecting applicable surfaces is cheap and short-circuits a doomed run. If there is no
   claims doc, report that and STOP — do not call the Workflow.
3. Otherwise **call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<app + how to run it>", claimsDoc: "<the actual claimed-functionality text or a path to it>", surfaces: ["cli"|"mcp"|"gui" ...applicable], ambiguousClaims: [<claims flagged in the gate>], maxIterations: <N>, budget: "<ceiling or ''>", testerModel: "<cross-family model, or omit for the GPT-5.5/GEN default>", allowUnisolated: false }`.
   This is an explicit skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   - **The build, derive, fix, and honesty-self-check judgment phases run on `model: 'opus'`** — Douglas's
     delegation policy reserves Opus for the load-bearing calls (compiling claims into tasks without leaking the
     implementation, root-causing a failing cell, judging whether the eval actually flipped under damage). The
     **tester** phase runs on a **cross-family model, default GPT-5.5 / GEN** (`--tester-model` overrides within
     the rule) — it MUST be a different family than the Opus fixer and capable enough that a failure means the
     app, not a weak tester; the builder's own family is never a valid tester. That is the whole independence
     guarantee.
   - The Workflow's first fix creates and removes a scratch worktree to PROVE isolation before any fix runs; if
     `stopReason` comes back `no_isolation_available`, that is Douglas's call (AskUserQuestion: commit first and
     re-run for isolation, recommended; or re-run with `allowUnisolated: true` accepting fixes touch the real
     tree). Only re-invoke with `allowUnisolated: true` after he answers.
4. **Report the result** per Step 7 / "Final report" below. The matrix is the report. Never claim "fully
   tested" — state which cells were proven at which tier over how many iterations, and which remain
   failed/flaky/blocked/ambiguous or carry tier-3 judge uncertainty.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'user',
  description: 'Full-claimed-functionality proof loop: build/verify CLI+MCP surfaces -> derive tasks two-step from the claim + build coverage matrix -> a fresh independent GPT-5.5/GEN tester exercises every cell across CLI/MCP/GUI with tiered assertions -> fix failing cells (systematic-debugging+TDD) in an isolated worktree with re-derived tester wording -> inject a regression to confirm the eval actually flips -> loop until proven/blocked or the cap hits; report the honest coverage matrix',
  phases: [
    { title: 'Build Surfaces' },
    { title: 'Derive & Matrix' },
    { title: 'Test' },
    { title: 'Fix' },
    { title: 'Honesty Check' },
  ],
}

const TARGET = args.target
const CLAIMS_DOC = args.claimsDoc || ''
const SURFACES = Array.isArray(args.surfaces) && args.surfaces.length ? args.surfaces : ['cli', 'mcp', 'gui']
const AMBIGUOUS = Array.isArray(args.ambiguousClaims) ? args.ambiguousClaims : []
const MAX_ITERATIONS = args.maxIterations || 8
const BUDGET = args.budget || ''
const ALLOW_UNISOLATED = args.allowUnisolated === true
const PER_CELL_RETRY_CAP = 3
// Tester model: cross-family from the Opus fixer (that's the independence guarantee). Default GPT-5.5/GEN;
// override within the rule, never the builder's own family.
const TESTER_MODEL = args.testerModel || 'gpt-5.5-gen'

// --- Phase schemas (JSON-schema-validated agent output, spar/hone/probe pattern) ---

const BUILD_SCHEMA = {
  type: 'object',
  properties: {
    surfaces: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          surface: { type: 'string', enum: ['cli', 'mcp', 'gui'] },
          applicable: { type: 'boolean' },
          built_or_present: { type: 'string', enum: ['already_present', 'built_this_pass', 'not_applicable', 'failed'] },
          live_smoke_passed: { type: 'boolean' },   // actually invoked / handshaked live, not read from code
          interface_description: { type: 'string' }, // what the tester will be told about this surface (no source)
          note: { type: 'string' },
        },
        required: ['surface', 'applicable', 'built_or_present', 'live_smoke_passed'],
      },
    },
  },
  required: ['surfaces'],
}

const DERIVE_SCHEMA = {
  type: 'object',
  properties: {
    features: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          claim: { type: 'string' },                 // the exact claimed feature, quoted/paraphrased from the doc
          ambiguous: { type: 'boolean' },            // true -> becomes blocked-ambiguous, not tested
          scenarios: { type: 'array', items: { type: 'string' } }, // Gherkin, derived ONLY from the claim
          tasks: {                                    // one per applicable surface
            type: 'array',
            items: {
              type: 'object',
              properties: {
                surface: { type: 'string', enum: ['cli', 'mcp', 'gui'] },
                task: { type: 'string' },             // concrete thing to do
                assertion: { type: 'string' },        // what proves the Then clause
                assertion_tier_preferred: { type: 'string', enum: ['programmatic', 'tool_verify', 'llm_judge'] },
                mutates_state: { type: 'boolean' },   // does executing it change persistent app state? drives scheduling + reset
              },
              required: ['surface', 'task', 'assertion', 'mutates_state'],
            },
          },
        },
        required: ['id', 'claim', 'ambiguous', 'tasks'],
      },
    },
    leaked_source: { type: 'boolean' },              // MUST be false: derivation must trace to the claim, not the code
  },
  required: ['features', 'leaked_source'],
}

const TEST_SCHEMA = {
  type: 'object',
  properties: {
    feature_id: { type: 'string' },
    surface: { type: 'string', enum: ['cli', 'mcp', 'gui'] },
    verdict: { type: 'string', enum: ['proven', 'failed', 'flaky', 'blocked'] },
    assertion_tier_used: { type: 'string', enum: ['programmatic', 'tool_verify', 'llm_judge'] },
    gui_verdict_mode: { type: 'string', enum: ['accessibility_verify', 'programmatic_state', 'llm_judge', 'n_a'] },
    state_asserted: { type: 'boolean' },             // actual resulting state checked, not just a success response
    evidence: { type: 'string' },                    // exact command/output/tool-result/screenshot ref observed
    failure_class: { type: 'string', enum: ['none', 'transient', 'systemic', 'inconsistent'] },
    notes: { type: 'string' },
  },
  required: ['feature_id', 'surface', 'verdict', 'assertion_tier_used', 'state_asserted', 'evidence', 'failure_class'],
}

const FIX_SCHEMA = {
  type: 'object',
  properties: {
    feature_id: { type: 'string' },
    surface: { type: 'string', enum: ['cli', 'mcp', 'gui'] },
    status: { type: 'string', enum: ['fixed', 'skipped', 'wont_fix'] },
    root_cause: { type: 'string' },
    red_green_evidence: { type: 'string' },          // failing-then-passing test proof
    change_summary: { type: 'string' },
    near_duplicate_of_prior_attempt: { type: 'boolean' }, // loop/duplicate detection
    reason: { type: 'string' },
  },
  required: ['feature_id', 'surface', 'status', 'near_duplicate_of_prior_attempt'],
}

const PREFLIGHT_SCHEMA = {
  type: 'object',
  properties: {
    is_git_repo: { type: 'boolean' },
    target_tracked: { type: 'boolean' },
    can_isolate: { type: 'boolean' },                // true ONLY if a real worktree was created + proven, then removed
    reason: { type: 'string' },
  },
  required: ['is_git_repo', 'target_tracked', 'can_isolate', 'reason'],
}

const HONESTY_SCHEMA = {
  type: 'object',
  properties: {
    injected_regression: { type: 'string' },         // what was deliberately broken (feature disabled / MCP tool corrupted)
    target_cell: { type: 'string' },                 // feature_id + surface whose verdict should flip
    verdict_flipped_to_fail: { type: 'boolean' },     // the load-bearing check
    regression_restored: { type: 'boolean' },         // MUST be true before finishing
    eval_is_honest: { type: 'boolean' },              // false if the verdict did NOT flip -> harness is fake, dominates report
    evidence: { type: 'string' },
  },
  required: ['injected_regression', 'target_cell', 'verdict_flipped_to_fail', 'regression_restored', 'eval_is_honest'],
}

// --- Prompts ---

function buildPrompt(target, surfaces) {
  return `You are giving an app the interface SURFACES it needs so a fresh independent user-agent can drive it, ` +
    `then verifying each surface LIVE. TARGET: ${target}\nAPPLICABLE SURFACES: ${JSON.stringify(surfaces)}\n\n` +
    `For each applicable surface the app lacks: invoke the "/make-cli" skill to add a CLI, and the "/make-mcp" ` +
    `skill to add an MCP server -- actually use those skills, do not hand-roll a substitute. For each surface ` +
    `(built this pass or already present), SMOKE-TEST IT LIVE, never by reading the generated code: actually ` +
    `invoke the CLI and confirm it produces structured, machine-parseable output; actually connect to the MCP ` +
    `server over its real transport and complete a full initialize handshake; for the GUI, confirm a local ` +
    `instance stands up and is reachable. A surface that was built but does not respond live is not a surface ` +
    `-- set built_or_present='failed' with a note.\n\n` +
    `For each working surface, write a concise interface_description a user with NO source access could act on ` +
    `(commands/flags, MCP tool names + their inputs/outputs, the GUI URL + what's on screen) -- this is exactly ` +
    `and only what the independent tester will be given. Do NOT include source, file paths into the code, or ` +
    `implementation detail in it. Stay scoped to the target; no elevated permissions; leave git status clean.`
}

function derivePrompt(target, claimsDoc, surfaces, ambiguous) {
  return `Derive an acceptance-test matrix for an app, tracing EVERY task to the app's CLAIMED functionality ` +
    `and NEVER to its implementation -- you must not read the source, and any task that could only be written ` +
    `by looking at the code means the claim is under-specified.\n\nTARGET: ${target}\n` +
    `CLAIMED-FUNCTIONALITY DOC (the only statement of what the app should do):\n${claimsDoc}\n\n` +
    `APPLICABLE SURFACES: ${JSON.stringify(surfaces)}\n` +
    `ALREADY FLAGGED AMBIGUOUS (carry forward as ambiguous=true, do not invent tasks for these): ${JSON.stringify(ambiguous)}\n\n` +
    `TWO STEPS, per claimed feature:\n` +
    `1. Write natural-language Gherkin-style scenarios (Given/When/Then) purely from the claim, from a user's ` +
    `stance, referencing only what the doc promises -- no internal function, code path, or commit.\n` +
    `2. Compile each scenario into a concrete executable task PER APPLICABLE SURFACE, each with the assertion ` +
    `that would prove its Then clause, a preferred assertion tier (programmatic state/API check > ` +
    `structured tool-verify > llm_judge as last resort), and mutates_state=true if executing the task changes ` +
    `the app's persistent state (a write/create/delete/config change) -- mutating tasks are scheduled serially ` +
    `with state resets so one cell's leftovers cannot decide another cell's verdict.\n\n` +
    `If a claim is too vague to have an observable pass/fail (e.g. "supports advanced search" with no ` +
    `specifics), set ambiguous=true rather than guessing an interpretation and grading against your own guess.\n\n` +
    `Every feature x surface pairing is a MATRIX CELL that starts empty (a claim to prove, never assumed). ` +
    `Set leaked_source=false and mean it: if you found yourself needing the source to write a task, flag that ` +
    `feature ambiguous instead. Report the features with their scenarios and per-surface tasks.`
}

function testerPrompt(target, feature, surface, interfaceDesc, claimsDoc) {
  return `You are a FRESH, INDEPENDENT user of an app. You have NO access to its source code, commit history, ` +
    `or the builder's intent -- only the app itself, its claimed-functionality doc, and the interface ` +
    `description below. You cannot and must not try to read the implementation; judge ONLY by what the app ` +
    `actually does when you drive it.\n\n` +
    `APP + HOW TO RUN IT: ${target}\n` +
    `CLAIMED FUNCTIONALITY (what a user is promised):\n${claimsDoc}\n` +
    `SURFACE TO USE: ${surface}\n` +
    `INTERFACE DESCRIPTION:\n${interfaceDesc}\n\n` +
    `FEATURE UNDER TEST: ${feature.claim}\n` +
    `TASK (${surface}): ${JSON.stringify(feature.taskFor)}\n\n` +
    (surface === 'cli'
      ? `CLI: run the real command. Demand structured, machine-parseable output stating exactly what changed -- ` +
        `exit code 0 with silence is NOT proof. Where output is unstructured, run an INDEPENDENT verification ` +
        `command/query to confirm the actual resulting state. Use exit codes to tell a retryable failure from a ` +
        `systemic one.\n\n`
      : surface === 'mcp'
      ? `MCP: connect over the REAL transport (stdio/SSE/HTTP) with a full initialize handshake -- never call ` +
        `handlers in-process. MCP has no protocol session: track any state HANDLE a creation-tool returns and ` +
        `pass it on the follow-up calls that need it. Assert the actual resulting STATE via a read-tool or ` +
        `side-channel -- a success response alone is "responds," not "responds correctly."\n\n`
      : `GUI: use @playwright/mcp against a LOCAL instance, in a FRESH browser session/profile (stale cookies ` +
        `and sessions from a prior cell are a documented false-verdict source) -- prefer the accessibility-tree ` +
        `snapshot + the browser_verify_* assertion family for deterministic non-visual checks. If the app's ` +
        `real DOM/backend state is queryable, verify that programmatically. Fall back to an LLM-judge verdict ` +
        `ONLY when no ground truth is queryable, and say so; when you must judge, grade each Then clause as ` +
        `its own criterion against the task goal, the action sequence with URLs, the final accessibility tree, ` +
        `and the first + last screenshots (a holistic pass over one screenshot is a known weak grader). Record ` +
        `gui_verdict_mode accordingly.\n\n`) +
    `SUCCESS ASSERTION -- use the most reliable tier that applies, cheapest first: (1) programmatic state/DB/` +
    `API check, (2) structured tool-verify, (3) llm_judge only as last resort. Record assertion_tier_used and ` +
    `set state_asserted=true only if you checked the actual resulting state (not just a success response). An ` +
    `llm_judge verdict is inherently less certain -- do not present it as equal to a programmatic proof.\n\n` +
    `Return a verdict: 'proven' (you completed the claimed task and the assertion held), 'failed' (it did not ` +
    `do what was claimed -- give the exact evidence), 'flaky' (inconsistent across attempts), or 'blocked' ` +
    `(you could not even attempt it -- say why). Classify any failure as transient (env/credential/one-off) or ` +
    `systemic (the app genuinely does not do this) or inconsistent. Give the exact command/output/tool-result/` +
    `screenshot reference you observed as evidence -- never a hypothetical.`
}

function fixPrompt(target, cell, priorAttempts) {
  return `A fresh independent user-agent could not complete a CLAIMED feature on a surface. Fix the APP so the ` +
    `claim becomes genuinely true -- you do NOT see and MUST NOT edit the acceptance check the tester uses; ` +
    `make the claimed behavior real, do not make a check pass.\n\n` +
    `TARGET: ${target}\nFAILING CELL: ${JSON.stringify(cell)}\n` +
    (priorAttempts.length
      ? `PRIOR FIX ATTEMPTS ON THIS CELL (avoid repeating -- if your fix would be near-identical to one of ` +
        `these, set near_duplicate_of_prior_attempt=true and stop, the cell is blocked): ${JSON.stringify(priorAttempts)}\n\n`
      : '') +
    `Use rigorous discipline: root-cause first (do not patch the symptom), reproduce with a FAILING test ` +
    `before changing implementation (RED), make the minimal change that makes it pass (GREEN), then confirm the ` +
    `target's own existing tests still pass. Do this in the isolated worktree provided; never the caller's main ` +
    `tree. Make ONLY the change this cell requires -- no unrelated refactors or drive-by cleanup. If the target ` +
    `keeps a tracked mirror elsewhere in this repo's convention, keep it in sync. If the fix would require ` +
    `bypassing a safety mechanism, or the claim is genuinely ambiguous, or your attempt duplicates a prior one, ` +
    `report status 'skipped'/'wont_fix' with a reason instead of forcing it. Never commit.\n\n` +
    `Report status (fixed/skipped/wont_fix), root_cause, red_green_evidence, change_summary, and ` +
    `near_duplicate_of_prior_attempt.`
}

function preflightPrompt(target) {
  return `Before any fix runs, PROVE whether git-worktree isolation is actually possible for this target -- the ` +
    `fix loop's whole safety guarantee depends on it, and assuming it works instead of proving it is how a ` +
    `prior run silently edited a real main tree while claiming isolation. TARGET: ${target}\n\n` +
    `Run real commands, do not infer: (1) is the target inside a git working tree (git -C <dir> rev-parse ` +
    `--is-inside-work-tree)? (2) is the target's OWN content tracked/committed, not just an ancestor directory ` +
    `(git -C <dir> ls-files -- <path>)? (3) ACTUALLY git worktree add <scratch> HEAD, confirm with your own ` +
    `eyes that the target's real files are present in it, then remove it (git worktree remove --force, then ` +
    `prune). Report is_git_repo, target_tracked, can_isolate (true ONLY if step 3 proved it), and reason in ` +
    `plain language if can_isolate is false.`
}

function honestyPrompt(target, provenCell) {
  return `Run the mandatory eval-honesty self-check: an eval whose score does not move when you deliberately ` +
    `damage the target is a FAKE eval measuring nothing. TARGET: ${target}\n` +
    `A cell currently reported PROVEN: ${JSON.stringify(provenCell)}\n\n` +
    `In the isolated worktree, deliberately inject a regression that should break exactly that cell -- disable ` +
    `the known-good feature, or corrupt the MCP tool's output. Re-run the SAME independent tester task for that ` +
    `cell and confirm its verdict FLIPS to fail. Then RESTORE the injected regression and confirm restoration ` +
    `(the cell works again). Set verdict_flipped_to_fail, regression_restored (MUST be true before you finish), ` +
    `and eval_is_honest=false if the verdict did NOT flip -- in which case the harness is proving nothing and ` +
    `this finding dominates the report. Report injected_regression, target_cell, and the evidence.`
}

// --- Run ---

// Build/verify surfaces (opus; invokes /make-cli, /make-mcp).
log(`Building/verifying surfaces ${JSON.stringify(SURFACES)} for ${TARGET}`)
const build = await agent(buildPrompt(TARGET, SURFACES), { phase: 'Build Surfaces', schema: BUILD_SCHEMA, label: 'build-surfaces', model: 'opus' })
const liveSurfaces = (build?.surfaces || []).filter(s => s.applicable && s.live_smoke_passed)
const interfaceBySurface = {}
for (const s of (build?.surfaces || [])) interfaceBySurface[s.surface] = s.interface_description || ''
const activeSurfaces = liveSurfaces.map(s => s.surface)

// Derive tasks + matrix from the CLAIM (opus). Never from source.
log(`Deriving Gherkin scenarios + per-surface tasks from the claim, building the coverage matrix`)
const derive = await agent(derivePrompt(TARGET, CLAIMS_DOC, activeSurfaces, AMBIGUOUS), { phase: 'Derive & Matrix', schema: DERIVE_SCHEMA, label: 'derive-matrix', model: 'opus' })
const features = (derive?.features || [])

// Build the matrix: feature x surface. ambiguous rows -> blocked-ambiguous; surfaces not active -> N/A.
const matrix = {}
for (const f of features) {
  matrix[f.id] = { claim: f.claim, ambiguous: !!f.ambiguous, cells: {} }
  for (const surface of SURFACES) {
    const applies = activeSurfaces.includes(surface) && (f.tasks || []).some(t => t.surface === surface)
    matrix[f.id].cells[surface] = {
      state: f.ambiguous ? 'blocked-ambiguous' : (applies ? 'empty' : 'N/A'),
      tier: null,
      guiMode: null,
      evidence: null,
      task: (f.tasks || []).find(t => t.surface === surface) || null,
      attempts: [],
    }
  }
}

// Isolation preflight (only needed once, before the first fix).
let isolated = true
let preflight = null

function pendingCells() {
  const out = []
  for (const fid of Object.keys(matrix)) {
    for (const surface of Object.keys(matrix[fid].cells)) {
      const c = matrix[fid].cells[surface]
      if (c.state === 'empty' || c.state === 'failed' || c.state === 'flaky') {
        if (c.task && c.attempts.length < PER_CELL_RETRY_CAP) out.push({ fid, surface, cell: c })
      }
    }
  }
  return out
}

let stopReason = null
let honesty = null
let iter = 0

// One tester dispatch for a cell. Used by the main loop and the pass^k confirmation re-run.
function runTesterCell(p, tag) {
  const feature = features.find(f => f.id === p.fid)
  const featureForTester = { claim: feature.claim, taskFor: p.cell.task }
  return agent(
    testerPrompt(TARGET, featureForTester, p.surface, interfaceBySurface[p.surface] || '', CLAIMS_DOC),
    { phase: 'Test', schema: TEST_SCHEMA, label: `${tag}-${p.fid}-${p.surface}`, model: TESTER_MODEL }
  )
}

// State hygiene (WebArena/BrowserGym lesson: cross-cell writes + stale sessions produce false verdicts):
// read-only cells run in parallel; state-mutating cells run one at a time against the instance.
async function runTesterBatch(cellList, tag) {
  const readOnly = cellList.filter(p => !(p.cell.task && p.cell.task.mutates_state))
  const mutating = cellList.filter(p => p.cell.task && p.cell.task.mutates_state)
  const resultByCell = new Map()
  const roResults = await parallel(readOnly.map(p => () => runTesterCell(p, tag)))
  readOnly.forEach((p, i) => resultByCell.set(p, roResults[i]))
  for (const p of mutating) resultByCell.set(p, await runTesterCell(p, tag))
  return resultByCell
}

for (iter = 1; iter <= MAX_ITERATIONS; iter++) {
  const pending = pendingCells()
  if (pending.length === 0) { stopReason = 'all_resolved'; break }

  // TEST: the fresh independent GPT-5.5/GEN tester exercises the pending cells -- read-only in parallel,
  // state-mutating serially (runTesterBatch). Re-derive nothing from source; each retry uses freshly-worded
  // task via the feature's own task text. Reset app state to baseline between iterations.
  log(`Iteration ${iter}/${MAX_ITERATIONS}: independent GPT-5.5/GEN tester exercising ${pending.length} pending cell(s) (read-only parallel, mutating serial)`)
  const testResults = await runTesterBatch(pending, `test-i${iter}`)

  const failedCells = []
  for (let k = 0; k < pending.length; k++) {
    const p = pending[k]
    const r = testResults.get(p)
    const c = matrix[p.fid].cells[p.surface]
    if (!r) { c.state = 'failed'; c.attempts.push({ iter, verdict: 'no-result' }); failedCells.push(p); continue }
    c.tier = r.assertion_tier_used
    c.guiMode = r.gui_verdict_mode || null
    c.evidence = r.evidence
    c.attempts.push({ iter, verdict: r.verdict, tier: r.assertion_tier_used, failure_class: r.failure_class })
    if (r.verdict === 'proven') { c.state = 'proven'; continue }
    if (r.verdict === 'flaky' || r.failure_class === 'inconsistent') { c.state = 'flaky' }
    else if (r.verdict === 'blocked') { c.state = 'blocked-ambiguous' }
    else { c.state = 'failed' }
    // Systemic failures escalate rather than retry blindly once the cap is reached; still queue for a fix.
    if (c.state === 'failed' || c.state === 'flaky') failedCells.push(p)
  }

  if (failedCells.length === 0) { stopReason = 'all_resolved'; break }

  // FIX: root-cause + TDD each failing cell in the isolated worktree. Prove isolation before the first fix.
  if (isolated && preflight === null) {
    log('Preflight: proving git-worktree isolation before any fix')
    preflight = await agent(preflightPrompt(TARGET), { phase: 'Fix', schema: PREFLIGHT_SCHEMA, label: 'preflight' })
    isolated = !!(preflight && preflight.can_isolate)
    if (!isolated && !ALLOW_UNISOLATED) {
      return {
        target: TARGET, isolated: false, preflight, stopReason: 'no_isolation_available',
        matrix, surfaces: build?.surfaces || [],
        note: 'The target cannot be isolated in a git worktree (' + (preflight ? preflight.reason : 'no usable preflight result') +
          '). /user refuses to silently edit the real tree. Douglas\'s call: commit the target first and re-run for ' +
          'full isolation (recommended), or re-run with args.allowUnisolated=true to let fixes touch the real files directly.',
      }
    }
    if (!isolated && ALLOW_UNISOLATED) {
      log('No isolation available -- proceeding UNISOLATED per explicit allowUnisolated=true. Fixes will touch the real target, not a worktree.')
    }
  }

  for (const p of failedCells) {
    const c = matrix[p.fid].cells[p.surface]
    const priorAttempts = c.attempts.filter(a => a.fixSummary).map(a => a.fixSummary)
    const feature = features.find(f => f.id === p.fid)
    const fixCell = { feature_id: p.fid, claim: feature.claim, surface: p.surface, task: c.task, last_evidence: c.evidence }
    log(`Iteration ${iter}: fixing ${p.fid}/${p.surface}`)
    const fix = await agent(fixPrompt(TARGET, fixCell, priorAttempts), { phase: 'Fix', schema: FIX_SCHEMA, label: `fix-i${iter}-${p.fid}-${p.surface}`, model: 'opus' })
    if (fix) {
      c.attempts[c.attempts.length - 1].fixSummary = fix.change_summary || fix.reason || fix.status
      if (fix.near_duplicate_of_prior_attempt || fix.status !== 'fixed') {
        c.state = 'blocked-ambiguous'   // duplicate fix or unfixable-in-scope -> blocked, stop retrying this cell
      }
      // a 'fixed' cell reverts to 'empty' so next iteration's tester re-proves it with fresh wording
      else c.state = 'empty'
    }
  }

  if (iter === MAX_ITERATIONS) stopReason = 'max_iterations'
}

// CONFIRMATION RE-RUN (pass^k, tau-bench): a single green flatters -- a cell that passed once was never
// exercised again, so flakiness behind a lucky first pass is invisible. Re-prove every proven cell once with
// fresh wording; a pass that does not repeat is flaky.
const toConfirm = []
for (const fid of Object.keys(matrix))
  for (const surface of Object.keys(matrix[fid].cells))
    if (matrix[fid].cells[surface].state === 'proven') toConfirm.push({ fid, surface, cell: matrix[fid].cells[surface] })
if (toConfirm.length) {
  log(`Confirmation re-run: re-proving ${toConfirm.length} proven cell(s) once (pass^2)`)
  const confirmResults = await runTesterBatch(toConfirm, 'confirm')
  for (const p of toConfirm) {
    const r = confirmResults.get(p)
    p.cell.attempts.push({ iter: 'confirm', verdict: r ? r.verdict : 'no-result' })
    if (r && r.verdict === 'proven') p.cell.confirmed = true
    else { p.cell.state = 'flaky'; p.cell.confirmed = false }
  }
}

// HONESTY SELF-CHECK: pick a proven cell, inject a regression, confirm the verdict flips, restore. Mandatory.
const provenCells = []
for (const fid of Object.keys(matrix))
  for (const surface of Object.keys(matrix[fid].cells))
    if (matrix[fid].cells[surface].state === 'proven') provenCells.push({ fid, surface, claim: matrix[fid].claim, task: matrix[fid].cells[surface].task })

if (isolated && provenCells.length) {
  const pc = provenCells[0]
  log(`Honesty self-check: injecting a regression against proven cell ${pc.fid}/${pc.surface} to confirm the verdict flips`)
  honesty = await agent(honestyPrompt(TARGET, pc), { phase: 'Honesty Check', schema: HONESTY_SCHEMA, label: 'honesty-check', model: 'opus' })
} else {
  log('Honesty self-check skipped: no proven cell to damage, or unisolated (cannot safely inject/restore without a worktree)')
}

// Flatten the matrix into a reportable shape.
const cells = []
for (const fid of Object.keys(matrix)) {
  for (const surface of Object.keys(matrix[fid].cells)) {
    const c = matrix[fid].cells[surface]
    cells.push({
      feature_id: fid, claim: matrix[fid].claim, surface, state: c.state,
      tier: c.tier, gui_mode: c.guiMode, evidence: c.evidence, attempts: c.attempts.length,
      confirmed: c.confirmed === true,   // pass^2: proven AND re-proven with fresh wording
    })
  }
}

const tally = cells.reduce((acc, c) => { acc[c.state] = (acc[c.state] || 0) + 1; return acc }, {})
const judgeUncertainCells = cells.filter(c => c.state === 'proven' && c.tier === 'llm_judge')

return {
  target: TARGET,
  surfaces: build?.surfaces || [],
  activeSurfaces,
  isolated,
  preflight,
  iterationsRun: iter > MAX_ITERATIONS ? MAX_ITERATIONS : iter,
  maxIterations: MAX_ITERATIONS,
  budget: BUDGET,
  stopReason: stopReason || 'exhausted',
  matrix: cells,
  tally,
  judgeUncertainCells,
  honestyCheck: honesty,
  evalIsHonest: honesty ? honesty.eval_is_honest : null,
  leakedSource: derive ? derive.leaked_source : null,
}
```

## Final report (what to tell Douglas)

**The Kitchen-Loop coverage matrix IS the report.** Present it as claimed-feature rows × CLI/MCP/GUI columns,
every cell marked, none silently omitted:

- **proven** — with WHICH assertion tier proved it (tier 1 programmatic / tier 2 structured tool-verify / tier 3
  LLM-judge, and for GUI cells which `gui_verdict_mode` decided it), and whether the pass^k confirmation re-run
  confirmed it (`confirmed`: ×2) or it stands at ×1. A tier-3 proof reads as less certain than a tier-1 proof;
  do not flatten them together.
- **failed** — diagnosis and what remains open.
- **flaky** — retried N times, inconsistent; its own bucket, never laundered into proven or failed.
- **blocked-ambiguous** — the claim was too vague to test, or the loop aborted on duplicate fix attempts, or the
  fix was unsafe in scope; this needs Douglas's call.
- **N/A** — the surface does not apply, with the reason.

Then:

- **Which cells carry irreducible LLM-judge uncertainty**, listed explicitly (`judgeUncertainCells`) — GUI cells
  with no queryable ground truth can only reach a tier-3 verdict, and the report says so rather than presenting
  them as certain.
- **The honesty self-check result** — that the eval's verdict was confirmed to flip under a deliberately
  injected regression this pass (`evalIsHonest`), and that the regression was restored afterward. If the verdict
  did NOT flip, that finding dominates the whole report: the harness proved nothing this pass, and every green it
  produced is suspect until the harness is fixed.
- **Never "fully tested" or "100% verified."** Mirror `/spar`'s "no new issues across the last 2 rounds",
  `/hone`'s "no change beat the baseline past noise", and `/probe`'s refusal of "fully tested." The honest
  statement is: *"every concrete claimed feature was exercised on surfaces X and proven at tier Y over N
  iterations; these cells remain failed/flaky/blocked/ambiguous and need a human call; these carry tier-3 judge
  uncertainty."*
- **Isolation status, stated plainly, every time — never assumed.** Whether the fix loop ran in a proven
  worktree (nothing touched the main tree) or unisolated (no repo / target untracked, Douglas explicitly
  authorized proceeding, fixes written directly to the real files). Never say "worktree removed" unless
  isolation was actually proven this run.
- Full absolute path(s) of everything changed, per the standing Files-list convention. Confirm every worktree was
  removed, any injected regression was restored, and the main tree's `git status` is clean.

---

*Tracked copy: also save this file to `claude-global-config/commands/user.md` (per the skills-are-tracked
convention) after a NASA scrub.*