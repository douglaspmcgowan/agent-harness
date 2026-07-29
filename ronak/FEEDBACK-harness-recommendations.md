# Harness recommendations — close the “opt-in proof” gap

**Type:** feedback / recommendations  
**Date:** 2026-07-26  
**Scope:** `claude-global-config` (global Claude Code harness)  
**Source:** Review of repo structure, `CLAUDE.md`, `VERIFY.md`, hooks, `skill-pathways.json`, `/spec` + `/app-verification-chain`, `/detective`, `CODEX-DELEGATION-LOG.md`, and project `feedback_*.md` patterns.

---

## Verdict

The harness is already strong at **not stopping early** (`keep-going` / ralph) and **not doing unsafe things** (secret, bash, authored-doc, firmware guards). The high-leverage gap is elsewhere: the best verification and build machinery (`/spec`, `/app-verification-chain`, `/user`, `/spar`, `/probe`) is **opt-in**, while a mediocre exit (flip `[x]`, write a Files list, stop) remains the default.

`keep-going` asks whether `WORK_QUEUE` still has open boxes. It does not ask whether P1 `AC-###` passed, whether an independent agent exercised the claim, or whether the UI was actually looked at.

**North star:** make “done” mechanically mean “proven against the oracle,” with the same fail-open discipline as `keep-going`.

Do not chase more slide/brand skills, another research command next to `/deep-search`, or more soft `CLAUDE.md` rules without a hook. Capability is ahead of default enforcement.

---

## What already works (keep)

| Area | Evidence |
|---|---|
| Autonomy loop | `hooks/keep-going.js` + `/ralph-loop` — session-scoped, fail-open, completion promise |
| Safety cluster | secret scans, dangerous bash, authored-doc protection, firmware guards |
| Spec-as-oracle (as a skill) | `/spec` with Product / Functional / Acceptance + `AC-###` graders |
| Proof pathway (as a skill) | `/app-verification-chain`, `/user`, `/spar`, `/probe` |
| Session forensics | `/detective`, `/daily-review`, `/handoff` |
| Offline hook self-test | `hooks/hook_guarantee.js` |
| Known failure taxonomy | `CODEX-DELEGATION-LOG.md` (zombies, wrapper re-dispatch) |

---

## Structural gap (highest impact)

**Best-in-class skills are opt-in; mediocre exits are the default.**

Concrete mismatch:

- Stop is gated on checkbox state (`WORK_QUEUE` / `CURRENT-TASK`).
- Proof is gated on Douglas typing `/app-verification-chain` or `/user`.
- An agent can mark work done and stop without touching the SPEC/AC matrix.

**Recommended fix:** a Stop (or PreCompact) gate that, when a project has `SPEC.md` and/or `VERIFICATION.md`, refuses stop unless P1 ACs are green — or explicitly waived as `[?]` with a one-line reason. Same philosophy as `keep-going`; different oracle. Fail open on missing SPEC (don’t trap every casual session); fail closed only when the oracle files exist.

That single change would leverage nearly everything already built.

---

## Ranked recommendations

### P0 — Ship these three first

#### 1. Stop gate tied to SPEC / AC matrix (when present)

| | |
|---|---|
| **Do** | Extend Stop (alongside or inside `keep-going`) so that if `SPEC.md` / `VERIFICATION.md` exists for the project, stop is blocked while P1 `AC-###` rows are unproven. Allow `[?]` waivers with reason. Fail open if no SPEC (casual sessions stay free). |
| **Why** | Closes the opt-in proof hole. Makes “done” mean proven. |
| **Signal** | Synthetic Stop JSON → exit 2 when P1 open; exit 0 when matrix green or waived; exit 0 when no SPEC. |
| **Risk** | Over-blocking — mitigate with presence-gated activation + explicit waivers. |

#### 2. Named `construct` pathway (resumable)

| | |
|---|---|
| **Do** | Add a chain to `hooks/skill-pathways.json` that is the front half of `/app-verification-chain`: grill/clarify → `/spec` → writing-plans → TDD build → smoke → independent verify → package. Wire `/pathway construct` with the same idempotent resume as harden-tail. |
| **Why** | Today only **harden-tail** is a named chain. The good build process lives in a long command body; it should be the easy, resumable default. |
| **Signal** | Second invoke of the same `(construct, target)` skips completed steps and continues. |
| **Risk** | Over-weight for tiny scripts — reuse Step 0 proportionality from `/app-verification-chain`. |

#### 3. Eval suite for load-bearing harness pieces

| | |
|---|---|
| **Do** | Add regression evals/tests for `keep-going.js`, `/spec` shape invariants, and 2–3 other load-bearing skills. Only `skills/html-slides/evals/` exists today against ~107 commands / ~45 skills; hooks have ~11 `*.test.js` files. |
| **Why** | The harness cannot tell when a “fix” quietly regresses Stop semantics or the SPEC oracle. |
| **Signal** | CI or `node` test run fails when keep-going exit codes or SPEC required sections drift. |
| **Risk** | Eval brittleness — keep cases small and behavioral (exit codes, section presence), not full golden transcripts. |

---

### P1 — High ROI next

#### 4. Hard cost / iteration budgets on autonomous loops

Ralph has `max_iterations`. Overnight/longrun docs warn about burn. Missing: a universal session/loop spend ceiling (token $, wall clock, or both) that hard-kills runaway loops.

**Do:** PreToolUse or Stop budget check with a per-loop / per-session ceiling; kill + surface reason when hit.  
**Why:** One stuck overnight can eat the month — especially on Codex/proxy paths.  
**Signal:** Armed loop hits ceiling → stop allowed, stderr names the kill reason, further agent turns don’t auto-continue.

#### 5. Visual / UI done-gate

Memory already encodes `visual_ui_check` and `render_check_after_layout`. Playwright setup exists. Nothing blocks “frontend done” without a screenshot or e2e signal.

**Do:** When the change set touches HTML/CSS/frontend routes, require a Playwright (or equivalent) pass + at least one looked-at screenshot path before Stop allows done.  
**Why:** Highest class of false dones on HTML/apps.  
**Signal:** Frontend-tagged WORK_QUEUE item cannot flip `[x]` without a recorded verify artifact.

#### 6. Closed loop: detective → durable fix queue

`/detective` finds reminder / dropped / automatable patterns. CLAUDE.md already forbids chat-only remedies. Findings do not automatically become harness work.

**Do:** Detective report ends by appending proposed hook/test/CLAUDE.md items to a harness `WORK_QUEUE` (or `BACKBURNER`) with evidence links.  
**Why:** The harness hardens from real sessions instead of waiting for the same failure twice.  
**Signal:** A detective run with ≥1 finding always leaves ≥1 unchecked harness queue item (or an explicit “no durable fix needed” line).

#### 7. Live hook liveness (per session)

`hook_guarantee.js` is an offline batch self-test. `/detective` already caught hooks that went silently dark mid-day.

**Do:** Session heartbeat — critical hooks (keep-going, secret guards, dangerous-bash) must have fired ≥1 this session or yell at Stop / statusline.  
**Why:** Security and autonomy guards failing open become visible in minutes.  
**Signal:** Disable a critical hook in a test settings overlay → session surfaces a liveness failure.

#### 8. Background-agent / Codex zombie watcher

`CODEX-DELEGATION-LOG.md` documents FM-1 (zombie “running”) and FM-2 (wrapper re-dispatch, 0-diff, &lt;30s). Recovery is manual.

**Do:** Always-on watcher (or PostToolUse / scheduled check) that cancels dead PIDs and flags 0-diff fast finishes as wrapper failures.  
**Why:** Stops a known, recurring token sink.  
**Signal:** Inject a ghost PID status → watcher cancels and logs; 12s 0-diff job → FM-2 alert.

---

### P2 — Worth doing once P0/P1 land

#### 9. SPEC drift / scope lock

Feedback like `dont_expand_lists` shows expansion past the ask.

**Do:** Gate that this turn’s diff must map to open P1 ACs or a written change request (`CHANGE.md` / `[?]` scope bump).  
**Why:** Less gold-plating; cleaner delivery even for personal apps.  
**Signal:** Unsolicited P2 feature without CR → Stop or PreToolUse warns/blocks.

#### 10. Global memory coherence

`feedback_*.md` is duplicated across multiple `projects/.../memory/` trees. Lean-index rule exists; consolidation doesn’t.

**Do:** One global feedback index + promotion path; per-project memory only for project-specific facts.  
**Why:** Fewer “I told you in the other project folder” misses; smaller always-on context.  
**Signal:** Duplicate feedback titles collapse to one canonical file with pointers.

#### 11. Contract / API surface as first-class oracle

`/spec` + `/user` cover claimed functionality across CLI/MCP/GUI. FE/BE schema drift can still pass happy-path ACs.

**Do:** Treat OpenAPI / schema contract tests as part of the verification matrix for multi-surface apps.  
**Why:** Silent breakage class that AC smoke misses.  
**Signal:** Breaking a response field fails a contract row before `/user` is paid for.

---

## Explicit non-goals (for this round)

- More slide / brand / fellowship / LinkedIn skills
- Another general research skill beside `/deep-search`
- Soft prose rules in `CLAUDE.md` with no hook, test, or gate
- Broadening permission allowlists as a substitute for better gates

---

## Suggested sequencing

```
Week 1–2   P0.1 SPEC/AC Stop gate (fail-open without SPEC)
           P0.3 keep-going + SPEC shape evals (smallest suite)
Week 3     P0.2 construct pathway in skill-pathways.json
Week 4+    P1.4 budgets → P1.5 visual gate → P1.6 detective→queue
           then P1.7 liveness → P1.8 zombie watcher
Later      P2 scope lock, memory consolidation, contract tests
```

---

## Design constraints (carry into any implementation)

1. **Fail open on harness self-error** — a broken gate must never trap the session (same as keep-going R1).
2. **Presence-gated proof** — SPEC/AC Stop only arms when oracle files exist; casual chats stay light.
3. **Waivers are first-class** — `[?]` / explicit waive with reason beats silent skip.
4. **Proportionality** — reuse `/app-verification-chain` Step 0; tiny scripts don’t earn `/user`.
5. **Durable fix over chat promise** — every accepted recommendation ends as hook, test, pathway, or queue item.
6. **Prove root cause before memory** — for Stop-hook changes, pipe synthetic JSON into the gate and assert exit codes before writing `feedback_*.md`.

---

## Open decisions for Douglas

- [ ] Should the SPEC/AC Stop gate live inside `keep-going.js` or as a sibling Stop voter?
- [ ] Default waive policy: who may mark `[?]` — only human, or agent with logged reason?
- [ ] Does `construct` replace invoking `/app-verification-chain` by hand, or wrap it?
- [ ] Budget units: subscription-safe iteration caps only, or also proxy/$ ceilings on GEN/Codex paths?
- [ ] Visual gate: all HTML touches, or only when WORK_QUEUE items are tagged `ui` / `frontend`?

---

## Appendix — evidence anchors in this repo

| Claim | Where |
|---|---|
| Only harden-tail pathway | `hooks/skill-pathways.json` |
| keep-going rules / fail-open | `hooks/keep-going.js` header R1–R14 |
| Spec + AC oracle design | `commands/spec.md`, `commands/app-verification-chain.md` |
| Independent user pass | `commands/user.md` |
| Hook offline guarantee | `hooks/hook_guarantee.js` |
| Codex zombie / wrapper FMs | `CODEX-DELEGATION-LOG.md` FM-1, FM-2 |
| Visual check as soft memory | `projects/.../memory/feedback_visual_ui_check.md`, `feedback_render_check_after_layout.md` |
| Scope expansion pattern | `projects/.../memory/feedback_dont_expand_lists.md` |
| Verification modes | `VERIFY.md` |
)
