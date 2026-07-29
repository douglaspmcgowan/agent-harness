---
description: Cache-efficiency + 1-hour-TTL counterfactual over your recent Claude Code sessions
---

Run the cache-efficiency check over the user's Claude Code transcripts.

```
"C:/Users/dmcgowa2/tools/nodejs/node.exe" "C:/Users/dmcgowa2/.claude/tools/cache-check.js" $ARGUMENTS
```

`$ARGUMENTS` = number of days to look back (default 2 if empty).

The script reads ONLY per-turn token counts + timestamps from `~/.claude/projects/**/*.jsonl` — never message content, so it's secret-safe.

After it runs, relay the three verdicts in one short block:
1. **Is caching working?** — the hit-rate line + HEALTHY/OK/POOR.
2. **Gap distribution** — how many turns fall in each TTL band.
3. **1-hour TTL?** — the NET dollar figure and the SWITCH/STAY recommendation.

Don't re-derive the math; the script prints it. If hit rate is POOR, point at the "Silent invalidators" list in `NASA_GSFC_Vault_1/Claude/Briefs/Claude prompt caching — cost & compaction break-even.md`.
