---
name: Durable state before compaction
description: When working against lists or per-item state, write to a project file before compaction risks losing the specifics
type: feedback
originSessionId: 5bda6e03-b70c-4379-bcc7-98ce2c2b8a6f
---

When a task involves tracking state across many discrete items — a list of articles to place, emails to process, tickets to triage, files to edit — write the list and its per-item state to a durable file in the project **before** context compaction can condense it. Never rely on transient tool results or in-context summaries to survive compaction.

**Why:** This already happened once on the AI Schools of Thought project. A list of ~50 TLDR articles and their placement state lived only in subagent tool results and my working context. After compaction, the summary preserved the existence of the list but not the per-article "placed / unplaced" mapping, so I mis-reported 4 articles as unplaced when all 4 were already on the site. The user caught it and flagged this as a pattern to avoid.

**How to apply:**

- At the start of any multi-item task, create (or append to) a log file in the project — e.g., `SOURCES.md`, `PLACEMENTS.md`, a `.csv`, or a tracked TodoWrite list if the work fits in one conversation.
- Record per-item state (status, target location, thread ID, URL) in the file in the same tool call as the action it describes. A placement without a log entry is unfinished work.
- Before reporting completion against a list, grep or read the log rather than recalling from context.
- For the AI Schools of Thought repo specifically, `PLAYBOOK.md` Phase 4 already prescribes this — `SOURCES.md` with columns `date_processed | source_type | sender/publication | subject/title | url | thread_id | status | placed_in`. Use it.
- Applies equally when dispatching subagents: the parent must write subagent findings to the log before the next step, not trust them to survive in-context.
