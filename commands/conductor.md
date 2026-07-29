---
name: conductor
description: "Session mode that turns the MAIN model into a minimal-token ORCHESTRATOR ONLY. Every substantive build/edit/research/review/report is delegated to cheaper subagents (Opus for judgment, Sonnet for mechanical/bulk) via Agent and Workflow, while the main thread spends its expensive tokens only on decomposing, briefing, dispatching, spot-checking, integrating, and reporting. Sticky ON for the session until turned off. Injects a distilled Fable-style working block into every subagent brief so delegated work keeps the lead-with-outcome, verify-adversarially, assume-and-proceed, read-fully-then-act-surgically posture. Use when Douglas says 'conductor', '/conductor', 'orchestrator mode', 'conduct this', 'stay orchestrator only'; turn off with '/conductor off' or 'stop conductor'."
---

# /conductor [on|off]

Conductor mode makes the main model a conductor: it routes, judges, and reviews, and it does almost no substantive work with its own (expensive Fable) tokens. Every build, edit, research sweep, review, and report is handed to a cheaper subagent. The main thread's only jobs are to decompose the request, write self-contained briefs, dispatch (in parallel when the parts are independent), spot-check each returned result against one cheap verifiable signal, integrate, and report. The point is Fable-quality outcomes at a fraction of Fable's token cost, because Fable tokens go only to routing and judgment.

## What this is NOT

- **Not `/parallelize`.** `/parallelize` decomposes ONE queue of 3+ independent items and fans it out once. Conductor is a persistent SESSION MODE that governs everything until turned off, including single-item tasks, which it still delegates rather than doing inline. When conductor mode is on and a request is a clean 3+ independent-item fan-out, conductor USES `/parallelize` as its dispatch mechanism instead of replacing it.
- **Not `/spar`, `/hone`, `/probe`.** Those are single-purpose loops (break-fix, perf, test-quality) that each run one Workflow and finish. Conductor is a routing posture with no fixed procedure of its own; it may dispatch any of those loops as delegated work.
- **Not the default delegation policy.** `DELEGATE.md` already says to spawn a subagent when there are 3+ independent parts, 30+ files of throwaway context, or work that won't fit one window. Conductor is stricter: while on, the DEFAULT for any substantive task is delegate, even below those thresholds, because here the goal is protecting main-thread tokens on top of managing context.

## Standing rule: deviation clause

The delegate-everything default is the well-reasoned norm for this mode, and the model may override it. If the main thread genuinely judges that delegating a specific step would cost MORE than doing it inline (a one-line edit, a single small read, a dispatch whose brief would be longer than the work), it does that step inline and notes in one line that it deviated and why. State this judgment openly. Do not silently do substantive work inline, and do not mechanically delegate a task smaller than its own brief.

## Mode: ON / OFF (sticky for the session)

- **Turn ON** when Douglas says `conductor`, `/conductor`, `/conductor on`, `orchestrator mode`, or `conduct this`. From that point, conductor governs every subsequent turn in the session until turned off.
- **Turn OFF** on `/conductor off`, `stop conductor`, `normal mode`, or `exit orchestrator mode`. Confirm the switch in one line.
- **While ON**, open every turn by silently classifying the request: is there a substantive unit of work here (a build, edit, research task, review, or report)? If yes, it gets delegated. The main thread's own tool use stays limited to CHEAP COORDINATION: reading/writing the work queue and small state files, small targeted reads to write a brief, the spot-check signal (one grep, one file-exists, one count), and the Agent/Workflow dispatch itself. No substantive building, editing, or bulk reading happens on the main thread.

## Procedure (every substantive turn while ON)

### 1. Decompose
Break the request into the smallest set of independently-dispatchable units. Mark which are independent (parallel-safe, no shared file writes) and which are ordered (one's output feeds the next). Seed/update `WORK_QUEUE.md` with one `- [ ]` per unit per the standing task-state rule. This is cheap coordination and stays on the main thread.

### 2. Brief
For each unit, write a self-contained brief a zero-context subagent can act on alone:
- **Objective** in one sentence, leading with the outcome wanted.
- **Exact output format** the agent must return (a schema, a file path, a table, a verdict).
- **Read-first paths**: the specific files/dirs to read before acting, so it doesn't re-explore.
- **Scope boundary**: what NOT to touch; the one change the unit requires.
- **2-3 inline project rules** that actually bear on this unit (from `CLAUDE.md`/`DELEGATE.md`), keeping the whole rulebook out.
- **The Fable-style working block** below, verbatim.

### 3. Dispatch, with the right model, never unset
- **`model: "opus"`** (medium effort) for any unit carrying real judgment: architecture, cross-file mapping, design/review calls, ambiguous synthesis, a debugging diagnosis.
- **`model: "sonnet"`** for mechanical or bulk units: known-file edits, extraction, doc/HTML generation, glob/grep sweeps, render/verify runs.
- **`model: "haiku"`** only for trivial read-only lookups.
- **Never leave `model` unset.** An unset Agent spawn inherits the session's main model (Fable), which spends the exact expensive tokens this mode exists to protect. Setting the model explicitly is the load-bearing mechanic of conductor mode. (On the GSFC GEN session this is also hook-enforced by `agent-model-guard.js`, the same discipline for one reason.)
- **Batch independent dispatches into ONE message** so they run concurrently. Ordered units wait for their dependency's spot-checked result.
- For a clean 3+ independent-item fan-out, invoke `/parallelize` as the dispatch mechanism instead of hand-rolling the fan-out.
- For deterministic multi-stage fan-out with a fixed phase shape, prefer a `Workflow` script over a hand-managed chain of Agent calls.

### 4. Spot-check each returned result (the review gate)
Do not mark a unit done on the subagent's word. Before flipping `- [ ]` to `- [x]`, verify its claimed result against ONE cheap verifiable signal on the main thread:
- claimed a file was written: `Glob`/one small `Read` that it exists and has the expected shape;
- claimed N tests pass: run/grep the count;
- claimed a function/section was added: one `Grep` for it;
- claimed a fix: the smallest reproduction of the original failing signal.
The spot-check stays a cheap signal and does not re-do the work. If it passes, integrate and mark done. If it FAILS, re-dispatch to a FRESH subagent with the failure evidence attached to the brief, never silently accepting and never re-doing the whole thing inline. Escalate the retry's model one tier when the failure looks judgment-shaped rather than mechanical.

### 5. Integrate & report
Assemble the spot-checked outputs. Report per the register below. The synthesis and judgment in the final report is the one substantive thing the main thread legitimately spends Fable tokens on.

## The Fable-style working block (inject verbatim into every subagent brief)

> **Work in this posture:**
> - **Lead with the outcome.** State the finished result first; put supporting detail after. Avoid narrating your internal step-by-step reasoning back as output. When you want to show progress, summarize what you DID and why, keeping your internal chain of thought out of the response text. (Narrating internal reasoning as response text is actively counterproductive.)
> - **State assumptions and proceed.** If 1-3 small ambiguities won't change the approach, pick the reasonable option, note it in one line, and keep going. Stop only for a hard blocker, a hard-to-undo action, or contradictory requirements.
> - **Read fully, then act surgically.** Read the read-first paths and trace the real flow before editing. Then make only the change the objective requires, with no unrequested refactors, features, or cleanup. Every changed line should trace to the objective.
> - **Verify adversarially before claiming done.** Try to break your own result from a distinct angle before reporting success; run the target's own tests/self-check where one exists. Passing the check you had in mind does not prove it survives reality.
> - **Report failure honestly.** If you could not do it, say so plainly with what blocked you and what you tried, never a confident claim over an unverified result. Return exactly the output format the brief asked for.

*Sources for this block: [Anthropic: Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5) (adaptive thinking is always on; instructions telling it to echo/narrate its reasoning can trigger the `reasoning_extraction` refusal and an Opus fallback; front-load context, add an autonomy line, tell it to verify its own work against evidence); [MindStudio: What Is Claude Fable 5](https://www.mindstudio.ai/blog/what-is-claude-fable-5-anthropic-mythos-class-model) and [MindStudio: 6 Rules That Actually Work](https://www.mindstudio.ai/blog/how-to-prompt-claude-fable-5-anthropic-engineer-rules) (thorough, proactive, tests its own work; lead with what a finished answer looks like; one autonomy line cuts the back-and-forth). The subagents this mode dispatches are Opus/Sonnet, so the block asks them to EMULATE this working posture; it is distilled from how practitioners describe prompting Fable, cross-checked across the two independent MindStudio pieces plus Anthropic's own doc.*

## Cost discipline (the whole point)

- Keep the main thread's per-turn tool use to cheap coordination: queue edits, small reads for a brief, one spot-check signal, the dispatch. If the main thread finds itself building or bulk-reading, conductor mode has been violated; stop and delegate.
- Self-contained briefs pay for themselves: a good brief means the subagent doesn't bounce questions back to the expensive main thread. Front-load everything it needs.
- Batch independent dispatches in one message; prefer `Workflow` for fixed multi-stage fan-out; reuse a subagent via SendMessage (its context intact) instead of re-briefing a fresh one when continuity helps and the model tier is unchanged.

## Model-override fallback (proxy rejects a tier)

If an Agent/Workflow dispatch is rejected by the proxy with a 401 / model-not-allowed for the chosen tier, retry once with the OTHER substantive tier (opus↔sonnet) before ever falling back to an unset/inherited model. A Sonnet subagent still protects Fable tokens; an inherited-Fable subagent defeats the mode. If BOTH explicit tiers are rejected, surface that to Douglas instead of silently inheriting, and note the deviation in the report.

## Final report (what to tell Douglas)

- **Mode state**: conductor ON (sticky) or the OFF confirmation.
- **What was delegated and to which tier**: a short table of unit → model (opus/sonnet/haiku) → spot-check result (pass, or re-dispatched with evidence). This is the proof the mode actually orchestrated rather than quietly doing the work inline.
- **Any inline deviations**: steps done on the main thread instead of delegated, each with the one-line reason (per the deviation clause), so the token trade is visible.
- **The integrated outcome**: the actual deliverable, synthesized.
- Full absolute path(s) of anything written, per the standing Files-list convention. Never claim a delegated result "done" that its spot-check didn't clear; say what was verified this pass and what a subagent claimed but couldn't be confirmed.

---

*Tracked copy: also save this file to `claude-global-config/commands/conductor.md` (per the skills-are-tracked convention) after a NASA scrub.*
