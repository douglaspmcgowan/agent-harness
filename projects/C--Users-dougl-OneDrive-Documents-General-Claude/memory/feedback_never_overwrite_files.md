---
name: Never overwrite user-edited files
description: Do not overwrite files the user has manually edited without reading current state first
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
Never overwrite a file the user has edited without reading its current state first. Always Read before Write on any file that may have been touched outside this session.

**Why:** User edits get silently destroyed when Claude writes stale content back.

**How to apply:** Before any Write to an existing file, Read it. If it differs from what you remember, show the diff and confirm before overwriting.
