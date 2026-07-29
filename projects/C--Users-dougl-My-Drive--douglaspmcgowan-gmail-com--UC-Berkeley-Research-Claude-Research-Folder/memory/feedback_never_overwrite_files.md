---
name: Never overwrite user-edited files
description: NEVER regenerate or overwrite files the user has manually edited. Only make the specific changes requested.
type: feedback
---

NEVER regenerate or overwrite files that the user has manually edited. Only make the specific changes requested — do not rebuild from scratch.

**Why:** User made manual edits to a PowerPoint presentation, then asked for additions/changes. Instead of patching in the requested changes, the entire file was regenerated from scratch, destroying all of the user's edits with no way to recover them. This caused significant frustration and lost work.

**How to apply:** When the user asks for changes to an existing file:
1. Read the current file first to understand its state
2. Only modify/add/remove what was explicitly requested
3. Preserve everything else exactly as-is
4. If structural changes are large, ask the user before overwriting
5. This applies especially to generated artifacts like presentations, documents, spreadsheets — anything the user may have manually edited after initial generation
