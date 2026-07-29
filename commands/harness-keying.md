---
name: harness-keying
description: "Verify and repair the project+session hook keying (the no-cross-contamination system) on this machine. Re-syncs the canonical hooks to the tracked mirror, migrates stray legacy root state into .claude/state/<project>/, validates .claude/projects.json, lists bound sessions, and runs the invariant guarantee. Use when Douglas says 'update the harness keying', 'check the hooks', 'harness keying', '/harness-keying', after adding/renaming a project or a hook, or whenever a session or Stop hook starts misbehaving."
---

# /harness-keying

Keeps the cross-session/cross-project contamination fix intact and up to date. The whole system is documented in
`NASA_GSFC_Vault_1/Claude/Engineer/Hook & session contamination — diagnosis and fix.md`.

## What this maintains
- **One** Stop hook (`keep-going.js`, wired at user scope) — no stale/duplicate Stop hooks.
- The shared keyer `~/.claude/hooks/hook-state.js` and the three state hooks that route through it
  (`keep-going.js`, `task-state-reminder.js`, `session-primer.js`), kept **byte-identical** in `~/.claude/hooks/`
  (active) and `claude-global-config/hooks/` (tracked mirror).
- The project registry `Claude NASA Folder/.claude/projects.json` (a project can span folders).
- Per-session bindings in `taskstate/sessions/<sid>.json` and the state under `taskstate/<project>/` (relocated from `.claude/state/`, which `hook-state.js` still reads as a fallback).

## Steps
1. **Run the maintainer** (does sync + migrate + validate + guarantee in one shot):
   `node "C:/Users/dmcgowa2/.claude/hooks/harness-keying.js" "C:/Users/dmcgowa2/Documents/Claude NASA Folder"`
   It prints `KEYING OK` (exit 0) or a list of `!` issues (exit 1).
2. **Read the output.** It reports: hooks synced home→tracked, any leftover Stop-hook scripts, files migrated into
   `taskstate/<project>/`, registry validity (every project folder exists, no folder owned by two projects, default
   valid), the bound sessions, and the `hook_guarantee.js` tally.
3. **If issues are reported, repair them:**
   - *Leftover Stop-hook scripts* → delete the stale ones from `~/.claude/hooks/` (only `keep-going.js` /
     `keep-going.test.js` belong); never add a second Stop hook (hooks merge additively → double-fire).
   - *Missing project folder / dir owned by two projects / bad default* → fix `Claude NASA Folder/.claude/projects.json`.
   - *Guarantee FAILED* → read the `FAIL` lines from `node "Claude NASA Folder/cad-forge/hook_guarantee.js"` and fix
     the specific invariant (one Stop hook, no PostToolUse-on-edit, project+session isolation, fail-open/no-trap,
     copies identical home==tracked, all paths resolve, case-insensitive resolution).
   - *A session running at the workspace root resolves to the wrong project* → drop
     `taskstate/sessions/<sid>.json` = `{ "project": "<id>" }`, then re-run.
4. **Adding or renaming a project:** edit `.claude/projects.json` (add the project + its member `dirs` + `vault`),
   mirror the row in `Claude NASA Folder/AGENTS.md`, then run this skill. Renaming → also `git mv` /
   rename `taskstate/<old>` → `<new>` and update any bindings pointing at the old id.
5. **Report** the final `KEYING OK`/issue summary and the guarantee tally.

## When to run it
After any change to: a hook in `~/.claude/hooks/`, the registry, the project layout, or the wiring in
`~/.claude/settings.json`; after adding a project/session; or when diagnosing "it stopped / it loaded the wrong
task / two sessions collided".
