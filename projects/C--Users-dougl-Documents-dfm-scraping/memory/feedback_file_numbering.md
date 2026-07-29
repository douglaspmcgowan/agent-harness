---
name: file_numbering_convention
description: When multiple files share a base name and differ only by (#), always use the highest-numbered (most recent) version
type: feedback
---

When the user references a filename like "main.tex" and there are multiple versions (main.tex, main (2).tex, main (3).tex, etc.), always read the highest-numbered version -- that's the most recent upload.

**Why:** The user uploads updated drafts with (#) suffixes and expects the latest version to be reviewed.
**How to apply:** Use Glob to find all matching files, then read the one with the highest number.
