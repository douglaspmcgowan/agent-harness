---
name: Session rollover
description: When user says "run session rollover", run ~/bin/rollover-session.ps1
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
When user says "run session rollover" → run `~/bin/rollover-session.ps1`.

**Why:** This script handles end-of-session cleanup, state archiving, and prep for the next session.

**How to apply:** Don't hand-roll rollover steps. The script is the single source of truth for what rollover means.
