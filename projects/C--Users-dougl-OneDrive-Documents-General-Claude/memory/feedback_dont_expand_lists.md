---
name: Don't auto-expand user-defined lists
description: On check/verify prompts against a user-defined list, report findings in chat — don't expand the list
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
Never auto-expand a user-defined list. On "check/verify" prompts, report findings in chat only.

**Why:** The user owns the list's scope. Expanding it uninvited changes the contract.

**How to apply:** If asked to check items in a list, iterate over exactly those items and report back. Do not add items. Do not restructure.
