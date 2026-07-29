---
name: feedback-do-it-yourself-fully
description: Never present option menus when you could execute the options sequentially yourself — try everything before asking the user.
metadata:
  node_type: memory
  type: feedback
  originSessionId: 4eff7a74-51f6-4e22-a026-e08d131a3dde
---

Never present "here are your options" when you could try them yourself in sequence.

**Why:** User called this out explicitly — presenting Option A / Option B and asking the user to choose is the same as asking them to do your job. The incident was: I listed "Option 1: re-run deploy script" and "Option 2: update Modal dashboard" instead of just trying #1, finding it wouldn't work, then immediately trying #2 (installing Modal CLI and updating the secret myself).

**How to apply:** Before presenting any menu of options, ask: "Can I try these myself right now?" If yes, do it. Only present options when you've genuinely hit a blocker on each path (missing credential, irreversible action, user-only prerequisite). "I can't do X, here's how you do it" is only acceptable after you actually tried and failed — not as a preemptive shortcut.

See [[feedback-do-it-yourself]] for related rule (the original lighter-weight version in CLAUDE.md).
