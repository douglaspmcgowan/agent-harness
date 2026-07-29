---
name: tactician
disable-model-invocation: true
description: "Douglas's read-only project strategist — the coach who reads the board and calls the next plays. For the current project it scans the raw state (git, tree, tests, docs, state files) for loose ends + hardening gaps, AND detects which of his skills already RAN on it (so it never re-recommends finished work), scores the gaps against a definition-of-done rubric, ranks forward moves by leverage, and maps each signal to the installed skill that would do the work — splitting the recommendations into two frames: 'complete it' (close the Definition-of-Done gaps) and 'level it up' (climb the maturity ladder beyond done). Ends at a bucketed pick-list and ASKS which to run; it detects and routes, never runs the audit/perf/test/break pass itself. Read-only, asks-never-executes. Use when Douglas says 'tactician', '/tactician', 'what should I run next on this project', 'what's the next move here', 'assess where this project stands', 'which skills to finish/level up X', 'find the loose ends', or 'which skill should I run next'."
---

# /tactician [target]

The first 70% of a build goes fast; the remaining 30% — the error paths, the tests, the docs that drifted, the scaffolding never cleaned up, the decision left half-made — looks done and isn't. `/tactician` is aimed at exactly that hard 30%, plus the move past merely-done. For the current project it reads the raw state (git, the tree, the tests, the docs, the state files), checks which skills have *already* been run against it, surfaces the loose ends and the hardening gaps as concrete signals tied to real files, ranks the forward moves by leverage, and maps each signal to the installed skill that would actually do the work — split into what *completes* the project and what *levels it up*. It ends at a pick-list and a question. It changes nothing.

Its two novel moves: it reads Douglas's *actual* installed-skill catalog and tells him which skill to run next for each thing it found; and it reads what skills *already ran* on this project, so it recommends the next play instead of one already made. Nothing else he owns does either.

## What this is NOT (the boundary — tactician detects and routes, it never does the doer's job)

- **Not `/frontier`.** `/frontier` is the multi-cycle EXPLORE driver: it builds the thing, stops at a six-heading menu, and actually *runs* the chosen leg, then loops. `/tactician` is a single read-only assessment that names specific skills tied to specific observed gaps and stops at one pick-list — one turn of the wheel, not staying at it. `/frontier` can *open* a cycle by borrowing `/tactician`'s scan to populate its menu; `/tactician` is upstream of it.
- **Not `/recon`.** `/recon` researches an *external field* (web) to help adopt or improve an approach, ending at a decision. `/tactician` looks *inward* at the current project's unfinished state and forward moves — no web, no landscape. It is recon's inward-facing sibling: recon maps what's out there to adopt; tactician maps what's left and what's next here.
- **Not `/detective`.** `/detective` is a forensic sweep across many past *session transcripts* for harness-level automation candidates. Tactician reads the current *repo/code state*, and looks forward rather than back.
- **Not `/investigate`.** `/investigate` root-causes *one past incident*. Tactician is project-wide and forward, not a single-failure diagnosis.
- **Not `/tech-debt-audit`.** That inventories what's *wrong now* across nine debt dimensions with file:line detail and writes `TECH_DEBT_AUDIT.md`. Tactician asks what's *left* and what's *next*, and when the signal is "the code is messy" it *routes to* tech-debt-audit rather than re-running its nine-dimension pass.
- **Not `/doctor`.** `/doctor` audits the *Claude Code harness* setup (secrets, hooks, skills, CI, MCP, memory), scores maturity, and *applies* fixes. Tactician is about the *product work's* loose ends and roadmap, and it *asks* rather than applies; when the gap is the harness itself, it recommends running /doctor.
- **Not `/spar`, `/hone`, or `/probe`.** Each of those *executes* one hardening technique — break-fix, perf, test-quality — on code in an isolated worktree. Tactician runs none of them; it detects the *signal* ("untested," "fragile," "slow") and *recommends the right one*, then asks.
- **Not `/historian`.** `/historian` mines the backward-looking build-log *event history* for insights. Tactician reads current forward-looking *project state*.

Hard boundary: if `/tactician` starts running the debt audit, the perf profile, the mutation pass, or the break-fix loop itself, it has collapsed into those skills. It detects, ranks, routes, and asks. That is the whole job.

---

## Phase 0 — Frame + resolve the target (1–2 lines, then proceed)

State which project this is scoped to (the current repo/working directory unless Douglas named another) and where it lives. If the target is genuinely ambiguous and more than one repo is in play, ask once; otherwise proceed on the obvious one and say which.

For a large repo, dispatch the Phase-1 mechanical scan to a subagent (its grep/git output stays in its own context; only the found signals come back) and synthesize — don't serialize a wide sweep or pull the whole tree into the main thread.

---

## Phase 1 — Deterministic loose-ends scan FIRST, then narrate (never the other way round)

Compute the mechanical signal set with grep/git BEFORE any model-authored ranking, so the findings are grounded in real files and not invented. This mirrors the signal-scan-first discipline `/hone`, `/probe`, and `/historian` already use. Collect:

- **In-tree markers** — `TODO` / `FIXME` / `HACK` / `XXX` / `BUG` comments, and commented-out code blocks. Each is a file:line.
- **Alternate-implementation / abandoned files** — `*_v2.*`, `*_old.*`, `*.bak`, `*-copy.*`, `layout_new.*`, sibling files that look like a superseded or half-finished parallel attempt.
- **Orphan modules / dead code** — for a suspected-dead symbol, grep its definition, then grep its usages; **zero non-definition callers = candidate dead code**. (Treat as a candidate only — see the false-positive caution below.)
- **Untested code** — files/functions with 0% or near-0% coverage if a coverage tool is available; otherwise source files with no corresponding test file.
- **Uncommitted / untracked work** — `git status --porcelain`: modified-but-uncommitted files, untracked source, and whether the branch is ahead/behind its upstream.
- **Swallowed errors** — empty `catch {}` / bare `except:` / `except Exception: pass` — error paths that silently drop.

Then **staleness / HEAD-divergence** (the "docs drifted behind the code" signal):

- For each doc that describes code (`README`, `STATUS.md`, `CURRENT-TASK.md`, `AGENTS.md`, design docs), compare its last-commit date to the last-commit date of the code it covers. A doc whose last commit predates the code is a **stale-doc** loose end.
- Scaffolding / generated / placeholder files untouched for a long stretch while the code around them moved are **dangling-scaffolding** loose ends.

Report Phase 1 as a flat list of raw signals, each with its file:line and signal type. Do not rank yet.

---

## Phase 1.5 — Skill-run history: what has ALREADY been done on this project

Before recommending any skill, detect which skills have already run against this target, so the pick-list is the next move rather than one already made. This is what separates a project-state-aware recommender from a static nudge. Evidence sources, cheapest first:

- **State-file + commit fingerprints** — `LOG.md` / `STATUS.md` entries and git commit messages that name a skill or its signature output (`spar` / "10 rounds", `probe` pass, `hone`, "solo-review", "design review", "tech-debt audit", "full-functionality proof" = `/user`, a `*_REVIEW*.md`, a `FEATURES.md`, a `TECH_DEBT_AUDIT.md`, a dashboard build).
- **Artifact fingerprints** — files a skill leaves behind: a `taskstate/` tree, a `_review` doc, a coverage report, an `e2e/` suite, a `RESUME.md` from `/package`.
- **Session transcripts** — only if state files and artifacts are inconclusive and the cost is warranted; scan for prior invocations against this project. Keep bulk out of the main context (grep/subagent), per the keep-bulk-out rule.

Record each detected skill as `ran` with its evidence, or `not detected` (absence of evidence is "not detected," not "never run" — say which it is). This feeds Phase 4: an already-run skill is suppressed **unless** the current state shows its target regressed — and a re-recommendation must name that regression as its "why" (e.g. "`/hone` ran, but STATE.md still shows `bus_frame` 54.3 vs mean 81 → re-run, weak-spot persists").

---

## Phase 2 — Definition-of-Done gap rubric (the gaps are the loose ends)

Score the current work against a definition-of-done checklist; each unmet item is a loose end. Use the DoD as the rubric for "what's left before this is actually complete", derived from the project's own declared intent (README / AGENTS.md / open `WORK_QUEUE` items / a STATUS "remaining" section), not a generic checklist:

- Tests pass on a clean checkout, and new/changed code has real coverage (not just green).
- Docs that describe the changed behavior are current (feeds off the Phase-1 staleness scan).
- No `TODO`/`FIXME` left in the touched code paths.
- No uncommitted/untracked work sitting on the branch.
- Error and edge paths handled, not swallowed.
- No debug prints, dead branches, or scaffolding left over from this change.
- The project is in a runnable / releasable state (it actually starts / builds / serves).

The best-practice way to build this list is to look backward at work that was marked done and later needed rework — Douglas's own `LOG.md` / `STATUS.md` discipline is exactly that record; read it if present and fold recurring rework patterns into the rubric for this project.

Then set the **second goalpost — the maturity ladder** (the "level it up" bar, separate from done): what the *next tier* looks like beyond merely complete — hardened against hostile input, faster, better-tested, docs polished, decoupled/reusable, presentable. Each rung builds on the previous, so a project still missing DoD items is not yet ready for level-up plays.

---

## Phase 3 — Rank by leverage, split into two frames, bucket by severity

An undifferentiated 30-item to-do dump gets ignored. Three moves prevent that:

1. **Split into the two goalposts**, so "finish it" and "gild it" don't blur:
   - **To complete it** — plays that close Definition-of-Done gaps (Phase 2). These lead; a project isn't ready to be levelled up until it's done at its current scope.
   - **To level it up** — plays that climb the maturity ladder beyond done.
2. **Bucket by severity within each frame**, so nothing critical drowns:
   - **must-fix** — correctness, broken/failing, silently-wrong, a live bug the scan surfaced (a property counterexample, a swallowed error on a real path). Critical items land here **regardless of effort** — the hard-but-important 30% does not get buried under quick wins.
   - **harden** — robustness/tests/debt/staleness: untested high-risk code, stale docs, dead code, fragile paths.
   - **next-feature** — the forward moves: the next thing to build, a half-made decision to finish.
3. **Within each bucket, rank by a leverage score** = **impact (1–5) × reach (1–5) × ease (1–5)** (max 125), where *impact* = how much it matters if left undone, *reach* = how many files/workflows it touches, *ease* = how quick/cheap it is (5 = quick). Multiplying separates a genuine high-leverage item dramatically from the noise instead of leaving a flat list.

**Every item carries its triggering signal as the "why"** — the concrete file/line/measurement that produced it (e.g. "coverage 0% on `accept.py:88` → /probe"; "`README.md` last commit 3 weeks behind `serve.py` → refresh docs"). No abstract "improve error handling" with nothing behind it. An item with no concrete signal does not go on the list.

---

## Phase 4 — Skill recommender: read the LIVE catalog, map signal → skill, gate on confidence

This is tactician's distinctive move. Read Douglas's **actually-installed** skills live — `~/.claude/commands/*.md` and `~/.claude/skills/*/SKILL.md` (plus Superpowers skills) — so the eligible-action set is his real catalog and a newly-installed skill is routable without editing this file. Where an existing named `/pathway` chain (`hooks/skill-pathways.json`, e.g. harden-tail = solo-review → probe → hone → spar) covers a cluster of gaps, recommend running that pathway rather than re-listing its steps. Then map the signals from Phases 1–3 to the skill that would do the work:

| Context signal (read live) | Recommend next |
|---|---|
| New/changed source with 0% or low coverage; suite thin | **/probe** |
| Code runs; want robustness against hostile/edge input | **/spar** |
| Slow build / loop / gate; a perf concern in the diff | **/hone** |
| God-files, duplicated logic, consistency rot smell | **/tech-debt-audit** |
| Missing CLAUDE.md / hooks / CI / secret-scan (harness gap) | **/doctor** |
| Frontend / UI files changed in the diff | **impeccable** |
| A failing test or a fresh bug | **superpowers:systematic-debugging** |
| About to start a feature | **brainstorming → writing-plans → TDD** |
| 3+ disjoint fixes queued | **/parallelize** |
| One known incident to root-cause / many sessions to sweep | **/investigate** / **/detective** |
| Uncommitted work piled up on a branch | **finishing-a-development-branch** / **/handoff** |
| Session ending / context-loss risk | **/handoff** or **/save-context** |
| Claimed features never end-to-end proven | **/user** / **/app-verification-chain** |
| "How do I adopt / get better at X" | **/recon** |
| Backward-looking build-story insight | **/historian** |

Rules for the recommender (these are the transparency constraints every skill-router in the field converges on):

- **Suppress the already-done.** A skill Phase 1.5 recorded as `ran` is not recommended again **unless** the state shows its target regressed; a re-recommendation must name that regression as its "why". This is the recommender's grounding in what already happened, not just what's available.
- **Confidence-gated.** Recommend a skill only when at least ~2 independent signals point to it. A single weak signal earns a mention; hold the recommendation until a second signal agrees.
- **State the "why" every time.** Each recommendation names the concrete signal that triggered it — never a bare "run /probe."
- **Never silently chain.** Tactician does not run the recommended skill. It surfaces it and lets Douglas pick.
- **On a tie, surface both.** When two skills fit equally, present both in the pick-list rather than silently choosing one.

---

## Phase 5 — The honest gate + the false-positive caution

- **Nothing-material gate.** If `git status` is clean, tests pass, there are no markers, docs are current, and there's no obvious next move — say "nothing material at the frontier this pass" and stop. Do not manufacture busywork to look thorough. This mirrors the data-sufficiency gates in `/hone`, `/probe`, and `/historian`.
- **Cold-start gate.** On a fresh repo with almost no history, don't fabricate a roadmap — say there isn't enough yet. If the project has no readable state AND no declared intent, ask Douglas for the one-line goal rather than inventing a Definition of Done.
- **Treat every loose-end as a candidate for review that a human still has to confirm.** Static scans miss runtime-dependent liveness: a "dead" symbol may be called via reflection, a dynamic dispatch, a config string, or an entry point; a "stale" doc may be intentionally stable. Include a short **"looks like a loose end but is probably fine"** aside (the same discipline `/tech-debt-audit` requires) for candidates you're flagging for a human eye rather than asserting outright.

---

## Phase 6 — Ask, don't execute (the stop)

Present the result as a bucketed pick-list and **stop at a question** — use `AskUserQuestion` (Douglas's preference for decision points), one selectable item per high-value finding, grouped as **complete-it / level-it-up** and within those **must-fix / harden / next-feature / run-a-skill**. Then wait. `/tactician` never executes the picked item itself — that's the whole point of the boundary: the moment Douglas picks, hand off to whatever actually does the work (a skill, a `/pathway`, `/frontier`'s loop, a plan, an edit), as a *new* action.

If the list is long, cap the pick-list at the top items per bucket by leverage score and say plainly how many were dropped below the cap — never silently truncate.

---

## Operating constraints (every run)

- **Read-only. Tactician changes nothing** — no edits, no commits, no running of the recommended skills. It scans, ranks, routes, and asks.
- **Every item traces to a concrete file/signal.** No abstract busywork; no "improve X" without the file/line/measurement behind it.
- **Ground every recommendation in what already happened** — the Phase-1.5 skill-run history, not just the available catalog. Never re-recommend a run skill without a named regression.
- **Ask, never auto-run, never silently chain.** This is the skill's identity, not a default — there is no `--auto` mode.
- **Honest gates.** Nothing-material and cold-start both stop cleanly rather than padding.
- **Signal-for-review, not fact** — flag candidates, don't assert liveness/staleness the static scan can't prove.
- **No antithesis framing** ("X, not Y"). State the positive claim.
- **Sensitive/local work stays local** — the scan is all local git/grep; no web, no egress.
- **Read the catalog live** for Phase 4 so the recommender reflects the skills actually installed today.

---

## Output contract

1. Frame + target (Phase 0)
2. Loose-ends + staleness signals, each with file:line (Phases 1–2)
3. Skills already run (with evidence) vs not detected (Phase 1.5)
4. The two goalposts — Definition of Done + the maturity ladder (Phase 2)
5. Ranked list split **to-complete-it / to-level-it-up**, bucketed must-fix / harden / next-feature, each item with its triggering "why" (Phase 3)
6. Skill recommendations — signal → skill, already-run-suppressed, confidence-gated, each with its "why" (Phase 4)
7. The honest gate outcome + the "probably fine" aside (Phase 5)
8. The `AskUserQuestion` pick-list, then stop (Phase 6)

---

*Tracked copy: also save this file to `claude-global-config/commands/tactician.md` (per the skills-are-tracked convention) after a NASA scrub.*
