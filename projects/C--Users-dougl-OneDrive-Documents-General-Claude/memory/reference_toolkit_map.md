---
name: claude-toolkit-map-what-s-installed-and-when-to-use-it
description: "Pointer to the one-stop toolkit reference file; read this before any non-trivial session to avoid hand-rolling something that's already automated"
metadata: 
  node_type: memory
  type: reference
  originSessionId: c5df5718-91a3-4d0a-baf3-631c2f647901
---

## Location
`G:\My Drive\UC Berkeley\Research\Claude Research Folder\claude-toolkit-map.md`

Also accessible via G-drive API at the same path. Last verified: 2026-05-20.

## What it contains
- All slash commands / skills with "when to invoke" guidance
- Active hooks (11 total) with trigger events and purposes
- MCP servers: local (filesystem, vercel, obsidian) and platform-managed (Gmail, Drive, DocuSign, Chrome, Preview, Registry, Session Mgmt, Scheduled Tasks)
- Memory rules index with trigger descriptions
- Templates and scaffolds (site-runtime-baseline, rollover script)
- Platform-level and anthropic-skills full list
- Use-case map: "when do I reach for what"

## When to use
Read it at the start of any non-trivial session, especially when:
- About to build something new (check if a skill or scaffold already exists)
- Setting up MCP or hooks (verify current state)
- Wondering what's automated (hooks table)
- Picking a model or delegation target

**How to apply:** Before hand-rolling anything, check this file. The global CLAUDE.md rule "check for installed skills, connectors, and plugins" should route here as the authoritative answer.
