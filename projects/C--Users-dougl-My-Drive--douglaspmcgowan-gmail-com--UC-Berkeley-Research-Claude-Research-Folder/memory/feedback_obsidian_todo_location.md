---
name: Obsidian To-Do.md location
description: User's long-form personal todo file location. Don't auto-edit; treat as inbox/brainstorm.
type: feedback
originSessionId: 24895fde-ce26-4073-baf7-26a80cb3841b
---

User keeps long-form personal todos and research brainstorms in:

**`C:\Users\dougl\My Drive (douglaspmcgowan@gmail.com)\Obsidian\Metropolis Pt. 1--The Maverick And The Test\To-Do.md`**

This is the **inbox / brainstorm** file. Don't auto-add things to it — user adds items themselves. The productivity-system `TASKS.md` (in `Claude Research Folder/`) is the curated, actively-tracked subset that `/productivity:update` syncs FROM To-Do.md.

## When to apply

- User says "add this to my todos" → ask whether they mean TASKS.md (curated, system-tracked) or To-Do.md (inbox, manual). Default: TASKS.md.
- User says "what's on my list" → show TASKS.md. To-Do.md only on explicit request because it's long-form and includes done items, half-formed thoughts, and personal items.
- `/productivity:update` is allowed to READ To-Do.md and propose new TASKS.md entries — never write to To-Do.md.

## Cross-references

- TASKS.md (productivity system) lives at `Claude Research Folder/TASKS.md`
- CLAUDE.md (working memory for productivity) at `Claude Research Folder/CLAUDE.md`
- Cron `d453a3a8` runs `/productivity:update` daily at 1:07 AM
