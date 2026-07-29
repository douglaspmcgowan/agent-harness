---
name: Claude Code Tool Workarounds
description: Known tool bugs and workarounds for Edit/Write EEXIST errors and file encoding issues
type: feedback
---

## Edit and Write Tool EEXIST Bug
The `Edit` and `Write` tools frequently fail with `EEXIST: file already exists, mkdir` errors in this project directory. This appears to be a persistent bug.

**Workarounds (in order of preference):**
1. Use `sed -i` via Bash for simple text replacements
2. Write a Python script to a temp file, then run it with `./venv/Scripts/python.exe`
3. Use the Agent tool to write/edit files (agents sometimes don't hit this bug)

**sed gotchas on Windows/Git Bash:**
- `sed -i 'N a\...'` (append after line N) does NOT preserve newlines -- everything ends up on one line
- For multi-line insertions, write a Python script instead
- `sed -i 's/old/new/'` works fine for single-line replacements
- Escape forward slashes in paths: `s/path\/to\/file/new\/path/`

## File Encoding
- LLM review JSON files contain Unicode characters that fail with cp1252 encoding
- Always open files with `encoding='utf-8'` in Python scripts
- The Bash tool runs under /usr/bin/bash, NOT PowerShell
- To run Python: `./venv/Scripts/python.exe script.py` or `powershell.exe -Command "cd '...'; & '.\venv\Scripts\python.exe' script.py"`

## Allowlist Settings
Project-level allowlist configured in `.claude/settings.json` with patterns for sed, grep, python, etc. scoped to the project directory. This prevents repeated permission prompts.
