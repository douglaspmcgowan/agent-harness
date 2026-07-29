---
name: Long-prompt discipline — write CURRENT-TASK.md first
description: On any message with 5+ items, write every item to CURRENT-TASK.md before touching code; one TodoWrite entry per item, not per theme
type: feedback
originSessionId: 504d357c-24ce-4e72-8b56-5e27db90b4af
---

On any message with 5+ items (especially voice/dictation):

1. First tool call is writing every item verbatim to `CURRENT-TASK.md` in the project root. No code until the file exists.
2. Build the TodoWrite list from that file — one todo per item, no thematic collapsing.
3. Never claim an item complete based on a related item passing. Verify each item individually.
4. On every session resume after compaction, read `CURRENT-TASK.md` before reading anything else.

**Why:** A 15-item voice prompt got compressed into 6 themes. Specific items like "move meter updated text outside frame" were silently dropped. The user had to re-ask multiple times across sessions. This is documented in psych-battery/LONG-PROMPT-RECOMMENDATIONS.md.

**How to apply:** The moment a message looks like a list (numbered, comma-separated, or long dictation), stop and write CURRENT-TASK.md. Do not read files first. Do not think first. Write the file first.
