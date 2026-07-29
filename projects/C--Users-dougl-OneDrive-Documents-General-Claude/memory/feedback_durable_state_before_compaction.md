---
name: Write durable state before compaction
description: On multi-step tasks approaching context limit, update CURRENT-TASK.md before compaction hits
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
On any multi-step task, update `CURRENT-TASK.md` before compaction happens. It must contain: (1) one-sentence goal, (2) completed steps with file paths, (3) remaining steps in order, (4) exact command/verifier to run next.

**Why:** Post-compaction sessions are blind to prior work. A stale or missing CURRENT-TASK.md means restarting from scratch.

**How to apply:** At the start of any task ≥5 items, write CURRENT-TASK.md first. Check context usage periodically on long tasks and update before it compacts.
