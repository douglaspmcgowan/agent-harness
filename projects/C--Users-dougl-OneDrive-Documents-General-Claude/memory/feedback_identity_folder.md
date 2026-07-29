---
name: identity-folder-off-limits
description: "G:\\My Drive\\Actual Documents\\Identity is completely off-limits — never read, write, search, or access it in any form"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 31f48557-5431-4b53-935f-f61f5cd1b1d9
---

**NEVER read, write, search, glob, or access** `G:\My Drive\Actual Documents\Identity` — off-limits to Claude in all contexts. Exclude from all file operations, greps, searches, and any cloud/git mirror. No exceptions. Subagents must be explicitly told to exclude it.

**Why:** Personal identity documents (IDs, sensitive personal records). User explicitly added this restriction.

**How to apply:** Block any tool call that targets this path. The `protect-ai-reference.js` hook enforces this at the tool level on Read, Grep, Glob, Write, Edit, Bash, and PowerShell. Even if the user asks you to access it in conversation, refuse and remind them of this rule.

See also: [[ai-reference-off-limits]], [[sensitive-vault-folder-off-limits]]
