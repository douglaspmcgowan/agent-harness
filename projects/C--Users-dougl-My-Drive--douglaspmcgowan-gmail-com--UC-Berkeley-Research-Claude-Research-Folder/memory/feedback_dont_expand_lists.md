---
name: Don't expand user-defined lists without being asked
description: When the user asks you to check/verify/review a list they defined, report findings but don't add new items to the list unless they ask
type: feedback
originSessionId: 5bda6e03-b70c-4379-bcc7-98ce2c2b8a6f
---
When the user asks "make sure you didn't miss any good ones" or "how up-to-date is X" on a list they already defined, the task is to **report** in chat, not to expand the list on the site. Give them the research findings; let them decide what to add.

**Why:** Confirmed on ai-industry-map project 2026-04-17. User asked me to verify freshness of the existing industry-maps list and check for missing ones. I went ahead and added 6 new maps directly to the site. User pushed back: "you put a bunch of maps in there. i don't need all of those. bring it back to the og list."

**How to apply:** For review/audit-style prompts on an existing list, default to: (1) do research, (2) report findings in chat, (3) ask which ones to add before editing. Only directly edit when the user phrases it as "add X" or "update Y."
