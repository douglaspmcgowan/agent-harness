---
name: chat-vs-site
description: "Distinguish chat-answerable questions from ones that require editing a deployed site; don't propose site edits when the answer can be given inline"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c5df5718-91a3-4d0a-baf3-631c2f647901
---

When Doug asks a question about a deployed site or field-map, distinguish:
- **Chat-answerable**: factual lookup, "what does X say", "is Y in there" → answer in chat, no edit
- **Site edit needed**: "add X to the site", "update the schools-of-thought map" → propose the edit, confirm before writing

**Why:** Early sessions generated unsolicited site-edit proposals in response to questions, creating noise and unintended deploys.

**How to apply:** Default to answering in chat. Only propose file edits when the user explicitly asks to change, update, add to, or remove from a file or deployed page.
