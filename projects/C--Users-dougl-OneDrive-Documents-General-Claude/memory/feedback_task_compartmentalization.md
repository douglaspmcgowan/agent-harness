---
name: task-compartmentalization
description: "Keep each session's/project's task state isolated — never merge or continue another session's CURRENT-TASK block"
metadata:
  node_type: memory
  type: feedback
  originSessionId: b05b66b3-fcc9-4eb1-bc72-1b1bf1a0aec7
---

`CURRENT-TASK.md` is **folder-scoped**: the `task-state-reminder` hook keys off the current working directory, so every session launched in the same folder reads and writes the **same** file. Shared catch-all folders (e.g. `C:\Users\dougl\OneDrive\Documents\General Claude`) therefore accumulate unrelated tasks from concurrent sessions, which then collide or get wrongly "continued."

**Why:** Doug runs multiple concurrent sessions. This has caused real confusion more than once — another session "continued the current task," and an unrelated "cheap-model research" task appeared inside the REDLINE task file. Project repos (berkeley-house, legal-solutions-website) avoid this because each has its own folder + own `CURRENT-TASK.md`.

**How to apply:**

- Prefer running a distinct workstream from **its own folder** so it gets its own `CURRENT-TASK.md`.
- In a shared catch-all file, head each task block with the **session/owner + date**, and if a block belongs to another session mark it `separate session — don't merge`. Treat blocks you didn't create as read-only.
- **Never** pick up or "continue" another session's `ACTIVE` block — act only on the task the current user message is about.
- Don't fold unrelated tasks into one workstream just because they share the file.
- Move finished tasks to `DONE` promptly so concurrent sessions don't re-pick them.

Related: [[feedback_durable_state_before_compaction]], [[feedback_long_prompt_discipline]], [[feedback_session_rollover]]
