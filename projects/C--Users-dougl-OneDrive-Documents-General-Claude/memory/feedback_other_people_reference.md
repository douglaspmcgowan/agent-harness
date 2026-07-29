---
name: other-people-reference-off-limits
description: 31_Business/Other People Reference.md in the Obsidian vault is completely off-limits to Claude
metadata:
  node_type: memory
  type: feedback
  originSessionId: deec23b0-d9ec-451c-a684-b76f69b4fa4b
---

`31_Business/Other People Reference.md` is off-limits — never read, search, glob, link to, or include in any mirror or export.

**Why:** User explicitly marked it as private/sensitive.

**How to apply:** Exclude from all vault reads, greps, globs. Subagents must be told explicitly. Hook `protect-ai-reference.js` enforces this at the tool level. See also [[ai-reference-off-limits]] (AI Reference folder) and [[26-sensitive-off-limits]] (26_Sensitive folder).
