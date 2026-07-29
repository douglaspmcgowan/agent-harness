---
name: Delegation checkpoints
description: Force the Codex two-question test at specific trigger moments instead of relying on in-flow recall
type: feedback
originSessionId: aabf6e38-a7e8-4caf-bb2c-c8fc7bd99438
---

The "Delegating to Codex / GPT-5.4" block in CLAUDE.md is clear about _when_ to delegate, but the failure mode is not forgetting the rule — it's failing to _consult_ it at the moments that matter. Doug caught this on the psych-battery pixel-art overhaul: 564-line first draft that matched the "Auto-delegate: first drafts ≥200 lines of code" trigger exactly, and I wrote it on Claude anyway.

**Why:** The task grew past the trigger mid-stream. It started as "read the guide and apply principles" (curation, Claude territory), then additive pixel-art scope pushed it past 200 lines. I never re-triaged. Compounding failure: I resumed after compaction without re-running the two-question test on the remaining work — the summary pointed me at "continue from where I left off" and I treated that as momentum rather than a re-triage point.

**How to apply — two forced checkpoints:**

1. **Before writing ≥200 lines of code or ≥500 words of prose in a single turn.** Before the first Edit/Write that will cross that threshold, stop and run the two-question test out loud: (a) can I write a self-contained brief covering everything Codex needs? (b) is there a verification signal that doesn't require Doug's judgment? If both yes and the work is bounded/academic/technical, invoke `/codex:rescue` with the brief stated inline. "It's not really a first draft, it's modifications" is exactly the rationalization to reject — the rule is about line count and brief distillability, not how I mentally label the work.

2. **On session resume after compaction.** Before the first substantive tool call post-resume, re-examine the remaining work against the delegation rules. The summary will make the work feel continuous; treat it as a fresh triage point instead. If the remaining scope is a ≥200-line mechanical draft, delegate it.

**Don't:**

- Don't treat "I already started on Claude" as a reason to finish on Claude. Switching costs are real but a 500-line first draft on Codex still beats a 500-line first draft on Claude even if I've written 100 lines already.
- Don't skip the checkpoint because the brief feels hard to write — if distilling the brief is harder than doing the task, that's the one genuine reason to keep it on Claude, per CLAUDE.md. But I have to _try_ the distillation, not just assume it's hard.
- Don't substitute "I'll be more careful" or "I'll remember next time" for a mechanism. Memory files are the mechanism; in-flow resolve is not.
