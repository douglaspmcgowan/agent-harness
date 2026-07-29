---
name: Track background tasks after dispatch
description: After dispatching ANY background task (Codex, sub-agent, background shell, pip install, model pull, etc.), immediately call ScheduleWakeup(180) and report status on every wake
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
After dispatching ANY background task — Codex job, sub-agent, background PowerShell/Bash command, long download, pip install — immediately call `ScheduleWakeup(delaySeconds: 180)`. Never dispatch and forget, and never use a wakeup longer than 180s as the first check-in.

**Why:** Background tasks are invisible after dispatch. Without a scheduled check, the user has to ask for status manually — which they should never have to do.

**How to apply:**
1. Dispatch task → `ScheduleWakeup(180)` in the same turn, every time, no exceptions
2. On wake: read the output file, report status to the user (success, in-progress, or failed)
3. If still running → reschedule another `ScheduleWakeup(180)` and report current progress
4. Never skip check-ins because you "estimated" the task would take longer — always check at 180s and reschedule if needed
5. For Codex: poll with `codex-companion.mjs status <job-id>` and report Phase + Elapsed + last progress line
