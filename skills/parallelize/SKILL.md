---
name: parallelize
description: Decompose a multi-part task into parallel sub-agent dispatches with explicit objectives, output contracts, and scope boundaries. Trigger when the user says "parallelize", "split this up", "do these in parallel", or when a task obviously has 3+ independent sub-parts — invoke proactively for the last case, don't wait to be asked (per Douglas's global CLAUDE.md default).
---

# /parallelize procedure

**Scope note:** this skill is about fanning work out to multiple SUBAGENTS. It does NOT cover batching
several independent tool calls (Read/Grep/Bash) into one message on the main thread — that's a separate,
always-on discipline governed by the system prompt directly, not something a skill invocation gates. If the
work doesn't need separate agents (just a few reads/greps you can batch yourself), skip this skill and just
batch the tool calls.

1. **Restate** the task as a bullet list of candidate sub-parts.

2. **Classify** each sub-part:
   - INDEPENDENT (no shared files, no data dependency) → parallel worker
   - DEPENDS ON another sub-part's output → sequential, after its dependency
   - SHARES a write target with another sub-part → merge into one worker

3. **Reject parallelization** and do it yourself if any is true:
   - Fewer than 3 independent sub-parts remain after classification
   - The total work fits comfortably in the current context window
   - It's a high-stakes refactor the user will need to review line-by-line

4. For each worker, draft a **dispatch packet** BEFORE calling the Agent/Task tool:
   - Objective (one imperative sentence)
   - Output format (exact schema the parent will consume, e.g. `"return markdown: ## Findings\n- <file:line>: <observation>"`)
   - Read-first: `<paths>`
   - Scope boundary: "Do NOT touch `<X>`. Do NOT run `<Y>`."
   - Key rules repeated inline (do NOT rely on CLAUDE.md inheritance — sub-agents don't reliably load it)
   - Stop condition: "Return after `<N>` tool calls or when you have `<result>`."

5. **Dispatch by default — don't pause for a go-ahead.** (Changed 2026-07-03: the old default waited for
   user approval before dispatching, which fought Douglas's own "auto-parallelize disjoint fixes without
   being asked" rule — see `[[feedback_auto_parallelize_disjoint_fixes]]`.) If the work already passed step 3
   (genuinely independent, fits comfortably, not a line-by-line-review refactor), state the N workers and
   their objectives in one line each and proceed straight to dispatch. Only pause for explicit approval when
   a worker would take a **destructive or hard-to-reverse action** (writes across many files, anything
   matching the "Executing actions with care" categories) — in that case step 3 should usually have already
   rejected parallelization anyway.

6. **Dispatch** all independent workers in a SINGLE assistant message (multiple Agent/Task tool calls in one turn). Never dispatch sequentially for independent work.

7. **Synthesize** on return: cite each finding back to its worker and source. Flag conflicts between workers explicitly. Do not silently merge conflicting results.

8. **Post-mortem**: if two workers returned overlapping findings, note it for the user — next run, merge those roles.
