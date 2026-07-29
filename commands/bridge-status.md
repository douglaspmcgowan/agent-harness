---
name: bridge-status
description: Manually inspect the local Codex research bridge and report pending requests, review drafts, and released results. Use this instead of the old recurring bridge polling automation.
---

# /bridge-status

Manually check the local Codex research bridge state. This command replaces the old recurring poller and should only run when explicitly triggered.

## Paths

- Requests: `C:\Users\dmcgowa2\.codex\research-bridge\requests\`
- Reviews: `C:\Users\dmcgowa2\.codex\research-bridge\reviews\`
- Results: `C:\Users\dmcgowa2\.codex\research-bridge\results\`
- Obsidian queue: `C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\Claude\Codex Research Queue\`

## What to do

1. Read the request, review, and result folders.
2. Summarize:
   - pending requests
   - review-pending drafts
   - newly released results
3. If there is a new result relevant to the current conversation, mention the result file path and summarize the key finding in 1-3 sentences.
4. If there is nothing new, say so briefly and stop.
5. Do not create automations, reminders, or background polling from this command.
6. Do not modify files unless the user explicitly asks you to.

## Output format

- `Pending:` <count>
- `Drafts awaiting review:` <count>
- `Released results:` <count>
- `Newest result:` `<full path>` or `none`

If a result is worth surfacing, add:

`Key finding:` <short summary>
