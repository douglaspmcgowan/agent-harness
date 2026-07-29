---
name: app-verification-chain
description: "The Schema Studio verification chain as a reusable pathway — the ordered fail-fast gauntlet a new app runs so it ships proven instead of hopeful, right-sized to the app up front (Step 0 proportionality gate) and leaving a durable VERIFICATION.md cross-reference matrix behind: /spec first (a machine-checkable SPEC.md that every later pass reads as its oracle) → build with the closed loop (superpowers:test-driven-development + an early nested-repo commit so a wipe is recoverable) → /user with real independence (source-blind cross-family tester, per-surface CLI/GUI/MCP matrix, regression-injection honesty check) → /spar + solo-review on every new surface (attack-found bugs, not read-found) → structural guards over review guards (make the code unable to reach what it must not, so no later regression can silently undo it) → a cheap smoke gate before the expensive independent pass → /package with a clean-clone-and-boot proof plus a recoverability check. Each step is a stage-gate with an entry condition and an exit gate, naming the exact skill to invoke and the signal that must hold before the next step starts. Use when Douglas says 'run the verification chain', 'app-verification-chain', 'take this app through the full chain', 'ship this app properly', 'the Schema Studio chain', '/app-verification-chain'."
---

# /app-verification-chain [app path or name]

A vibe-coded app is evaluated against whatever the last session happened to remember wanting, and declared done
the moment it looks done. This pathway replaces "looks done" with a fixed sequence of gates, each wired to a
written oracle, run in an order where every step consumes the artifact the previous one produced. It is the
Schema Studio build generalized into a checklist you apply to any future app — every step is an existing skill,
so this command is the glue that orders them and states the gate that must hold before the next one starts.

Run the steps IN ORDER. Do not advance to step N+1 until step N's gate holds. If a gate fails, stay on that step
(fix, re-run) rather than proceeding with a known hole — the whole value is that a later pass can trust an
earlier one's oracle.

**Each step is a stage-gate with two criteria** (deployment-pipeline discipline, Humble & Farley / Fowler): an
**Entry** condition that must already hold for the step to be worth starting, and a **Gate** (exit) that must
hold before the next step begins. A stage runs only once its Entry holds; it passes only on its Gate's actual
signal. The stages are ordered fail-fast — cheap, fast checks up front so a hole is caught before an expensive
independent pass pays to find it.

## Step 0 — Right-size the chain (proportionality gate)
- **Do:** before running anything, size the app and decide which stages run at full weight, which lighten, and
  which are `N/A`. The full chain assumes an app with real surfaces, untrusted input, and a portability claim.
  A throwaway one-file script with no external input does not earn a source-blind cross-family `/user` pass or a
  clean-clone `/package` proof; a shared library with no GUI has no GUI matrix column. Grade each stage:
  full / lightened / `N/A — reason`.
- **Why:** the test pyramid's own caveat is that its proportions adapt to the app, not a fixed ratio (Fowler;
  Dodds' trophy). Independence is the single most expensive stage — a fresh cross-family tester costs a proxy
  run, a source-blind setup, and a re-derived task each retry — so it earns its cost only when the app makes
  a real functional claim to an outside user. Right-sizing keeps the gauntlet proportional to what the app
  actually risks.
- **Deviation clause:** this staged order is the well-reasoned default, not a straitjacket. When a specific app
  genuinely calls for a different move than a stage prescribes (skip, reorder, substitute), surface the
  divergence and the reason in the report and proceed — do not silently comply or silently reroute.
- **Gate:** a one-line right-sizing decision per stage (full / lightened / `N/A — reason`) is written into the
  verification matrix (see Report) before Step 1 starts.

## Step 1 — /spec first (the shared oracle)
- **Entry:** the app's intended behavior is known well enough to write acceptance criteria (Step 0 done).
- **Do:** invoke `/spec` to produce `SPEC.md` with §Product / §Functional / §Acceptance, where every acceptance
  criterion has a stable `AC-###` id bound to a checkable grader.
- **Why:** `/user`, `/probe`, `/verify`, and `/design-review` all read this doc as ground truth. Without it,
  each later pass invents its own definition of "correct" and they silently disagree.
- **Gate:** SPEC.md exists, and every P1 user story has at least one machine-checkable `AC-###`.

## Step 2 — build with the closed loop
- **Entry:** SPEC.md exists with machine-checkable `AC-###` ids (Step 1's gate).
- **Do:** implement against the spec with `superpowers:test-driven-development` (red → green → refactor). Commit
  the app's own (nested) git repo EARLY, before the first risky operation.
- **Why:** the early base commit + on-disk transcripts are the only reason a mid-build data-loss is recoverable
  (Schema Studio's Phase-R wipe was recovered from exactly this). TDD makes "green" mean the spec's behavior.
- **Gate:** the AC-### tests exist and pass; a base commit exists on the app's own repo.

## Step 2.5 — smoke gate (cheap, before the expensive independent pass)
- **Do:** run the fastest possible whole-app boot check before paying for independence: start the app on a
  clean state, hit each surface it exposes ONCE with a trivial happy-path call (one endpoint request, one CLI
  `--help` + one real verb, one MCP `tools/list`, the GUI's index route returning 200), and confirm it comes
  up and answers. No coverage, no adversary — just "does it run and serve every surface at all."
- **Why:** fail-fast ordering (deployment pipeline, Humble & Farley / Fowler): the cheapest stage runs before
  the most expensive one, so a dead surface or a boot error is caught in seconds by the local run instead of
  by a cross-family proxy tester twenty minutes in. A `/user` pass that opens on an app that does not boot
  burns its whole budget discovering that.
- **Gate:** every surface returns a live response to one trivial call; the app boots from a clean state with
  the documented start command. A red smoke gate stops the chain here — fix before independence.

## Step 3 — /user with real independence
- **Entry:** the smoke gate is green (every surface boots and answers) — do not spend independence on a dead app.
- **Do:** invoke `/user` — a source-blind, cross-family tester (GPT via the GEN/NMC proxy) that sees only the
  running app + the claimed-functionality doc, exercises every claimed feature across the CLI / GUI / MCP
  surfaces, fills the coverage matrix, and runs the regression-injection honesty self-check (deliberately damage
  the app and confirm the verdict FLIPS, then restore).
- **Why:** a source-blind attacker proves claimed functionality the way a real user meets it; the injection
  check proves the eval itself is real rather than a rubber stamp.
- **Gate:** every claimed-feature × surface cell is proven / blocked / N-A (never silently omitted), AND the
  injection check flipped the verdict under damage.

## Step 4 — /spar + solo-review on every NEW surface
- **Entry:** the `/user` matrix is filled and its injection check flipped (Step 3's gate) — attack a proven-live app.
- **Do:** for each surface the app exposes (each endpoint, CLI verb, MCP tool, file path it reads/writes), run
  `/spar` (parallel breakers: input-fuzzing, state/ordering, resource, spec-contradiction) and a `solo-review`
  pass. Fix every real finding with `superpowers:systematic-debugging` + TDD, then re-attack.
- **Why:** Schema Studio's CRITICAL path-traversal and case-flip CUI-bypass were both found by attack, not by
  reading. Reading confirms the code you expected; attacking finds the input you didn't.
- **Gate:** two consecutive spar rounds find nothing new on each surface.

## Step 5 — structural guards over review guards
- **Entry:** two consecutive spar rounds found nothing new on each surface (Step 4's gate).
- **Do:** for every must-not-happen invariant (a component that must never see certain data, an endpoint that
  must never reach run files), prefer an ARCHITECTURAL guarantee — the code structurally cannot reach the thing —
  over a review/check that a future edit could remove.
- **Why:** the durable Schema Studio CUI wins came from architecture (the graph endpoint's index never loads run
  data, so it CANNOT leak it), which no later regression can silently undo. "The code can't reach it" outlives
  "a review checked it."
- **Gate:** each critical invariant is enforced by a structural fact (not just a test/assert), and you can name
  the structural reason it holds.

## Step 6 — /package with proof + recoverability
- **Entry:** every critical invariant holds by a structural fact you can name (Step 5's gate).
- **Do:** invoke `/package` to produce a portable repo, then PROVE it: clean-clone into a fresh temp dir and boot
  it with nothing but the documented quickstart. Then prove RECOVERABILITY: from the clean clone, confirm you can
  return to a known-good state — the base commit is reachable (`git log` shows it), and any first-run state the
  app writes (a data dir, a DB file, a cache) can be reset/reinitialized by a documented step so a bad run does
  not brick the install.
- **Why:** clean-clone-and-boot on a bare dir is the only portability claim that counts; anything else is "works
  on the machine that built it." And a pipeline that can ship but cannot roll back has no safe failure path
  (deployment-pipeline recoverability, Humble & Farley) — the early base commit from Step 2 is the rollback
  target, and this step proves it actually reaches a working state.
- **Gate:** a clean clone in a fresh dir runs the quickstart and the app comes up, AND a documented reset returns
  it to a known-good state from a deliberately-dirtied run.

## Flaky-test handling (shared policy for Steps 2–4)
A test that fails intermittently is worse than no test: it trains everyone to re-run until green, so the gate
stops meaning anything. Whenever a gate's signal is non-deterministic across identical runs:
- **Never advance on a re-run-until-green.** A gate passes only when its check is green on a clean run without
  retrying it into passing. `/user`'s pass^k confirmation re-run already encodes this — a single lucky green is
  not proven.
- **Quarantine, then root-cause.** Move the flaky check out of the blocking gate into a quarantine list (so it
  stops masking real failures), and treat the flakiness itself as a bug to diagnose with
  `superpowers:systematic-debugging`; muting it hides the very failure it is warning about.
- **Push the assertion down.** When a high-level (GUI/E2E) check is the flaky one, reproduce the underlying
  behavior with a lower-level deterministic test and let that be the real gate (Fowler: replicate the bug with a
  unit test so it stays dead; Dodds: a test should only fail for a useful reason). The brittle high-level check
  becomes a smoke signal, and the deterministic one becomes the oracle.

## Report — and leave a verification matrix behind
End with a per-step table: step → skill invoked → entry-held? → gate result (held / failed-and-fixed / blocked /
`N/A` per Step 0) → evidence (the command + its signal). Never report a step green on the intention to run it;
report it green only on the gate's actual signal.

**Write a durable `VERIFICATION.md` into the app repo** — a verification cross-reference matrix in the spirit of
the NASA SE handbook's VCRM (Requirements Verification Matrix, NASA/SP-2016-6105 Rev 2). One row per `AC-###`
acceptance criterion from SPEC.md; columns:
- **Method** — which of the four verification methods proved it: **Inspection** (read the code/config),
  **Analysis** (a structural argument, e.g. Step 5's "the endpoint's index cannot load run data"),
  **Demonstration** (a surface answered a real call — smoke/`/user`), or **Test** (an automated `AC-###` test).
  Record a structural guarantee as Analysis — its durability comes from the code's shape — so that durability stays legible.
- **Surface** — CLI / GUI / MCP / internal (mirrors the `/user` matrix columns; `N/A` where a surface does not exist).
- **Result** — proven / failed-and-fixed / blocked / `N/A`, with the evidence pointer (the command + its signal,
  or the structural reason).

This artifact is the thing the chain leaves behind: it maps every acceptance criterion to how it was verified and
outlives the run, so a later session (or the always-on gates) can see what was actually proven and by which
method, rather than re-deriving it. Keep it in the app repo next to SPEC.md; the always-on gates maintain the
proof it records.

## Notes
- This is a PATHWAY (an ordering + gates), not a re-implementation — every step delegates to the named skill.
- It pairs with the always-on gates (`dep-audit-gate`, `semgrep-diff-gate`, `test-green-gate`): those fire
  automatically per project via `.claude/gates.json`; this chain is the deliberate, whole-app pass you run once
  per app to establish the proof the gates then maintain.
