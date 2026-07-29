---
name: Codex avoidance rules (7 hard rules)
description: Seven situations where Codex must NOT be used — check before every dispatch
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
Before any Codex dispatch, check these 7 hard rules. If any applies, keep on Claude:

1. **Brief is mushy** — requirements aren't agreed yet. Agree first, delegate second.
2. **Iteration on existing draft** — Codex is for first drafts; iteration stays on Claude.
3. **Real credentials/secrets involved** — never delegate anything touching env vars, tokens, or prod deploys.
4. **Inside a `/loop`** — autonomous loops must not spawn Codex sub-agents.
5. **Personal tasks** — email, scheduling, finances, personal writing stay on Claude.
6. **The brief is harder to write than the task** — if you can't distill it clearly, do it yourself.
7. **No verifiable done-signal** — if the only check is "does this look right to a human," keep it on Claude.

**Why:** Codex dispatched incorrectly produces costly, hard-to-reverse output that still requires full Claude review to trust.

**How to apply:** Read this list before every `/codex:rescue` invocation.
