---
name: environment-preflight
description: Run a disposable preflight audit for the current project or a specified target folder before setup, debugging, build, or deploy work. Use when you want a cheap first pass that catches tooling, auth, config, and repo-shape problems before they pollute a longer session.
disable-model-invocation: true
---

# Environment Preflight

Use this skill only when the user explicitly asks for a preflight check, setup audit, environment audit, deploy readiness check, or start-of-session sanity pass.

Default target:
- If `$ARGUMENTS` is empty, use the current working directory.
- If `$ARGUMENTS` is present, resolve it as a target folder relative to the current working directory unless it is already absolute.

Primary goal:
- Run the cheap, disposable checks first.
- Catch environment and workflow blockers before the main build, research, or debug session grows expensive.

Operating rules:
- Keep this separate from feature implementation unless the user explicitly asks to continue into build work after the preflight.
- Do not expose secrets, tokens, or `.env` contents.
- Presence checks are fine; secret value reads are not.
- If a command cannot run because of sandbox, permissions, or network restrictions, record it as `SKIP` or `UNKNOWN` instead of pretending it passed.
- If a repo contains both `AGENTS.md` and `CLAUDE.md`, check whether the Claude entrypoint imports or mirrors the durable instructions rather than silently drifting.

Primary artifact:
- Write `preflight_report.md` at the target root.

Report format:
- `PASS`: ready and verified
- `WARN`: usable but likely to waste time later
- `FAIL`: clear blocker
- `SKIP`: could not verify here

Required sections in `preflight_report.md`:
1. Target and timestamp
2. Repo identity
3. Instruction/context files
4. Tooling checks
5. Auth and integration checks
6. Runtime/project checks
7. Risks likely to waste tokens
8. Recommended next action

Minimum checks:

Repo identity
- Current target path
- Whether this looks like a git repo
- Branch and dirty-state summary if git is available
- Presence of obvious project entrypoints such as `package.json`, `pyproject.toml`, `requirements.txt`, `server.js`, `index.html`, `.claude/launch.json`, `vercel.json`

Instruction and context files
- `CLAUDE.md`
- `CLAUDE.local.md`
- `AGENTS.md`
- `.claude/settings.json`
- `.claude/settings.local.json`
- `STATUS.md`
- Flag overlapping or duplicated context files that should be consolidated

Tooling checks
- `git`
- `python` or `py`
- `node`
- `npm`
- `gh`
- `vercel`
- `ffmpeg`
- `yt-dlp`
- Any other tool clearly required by project files or docs

Auth and integration checks
- GitHub auth status if `gh` is installed
- Vercel auth status if the repo appears deployable to Vercel
- Claude settings sanity if local Claude config exists
- Never print tokens, usernames are fine if already exposed by the tool

Runtime/project checks
- Whether a documented dev command can be identified from project files
- Whether a likely local-preview config exists
- Whether obvious required ports are already occupied, if the project docs name them
- Whether there are missing generated folders or expected assets that would block a local run

Token-waste checks
- Flag cases where setup/debug should happen in a fresh disposable session
- Flag bulky repo instructions that belong in skills instead of base memory
- Flag likely folder scans that should be replaced with a manifest

Recommended workflow:
1. Resolve the target directory.
2. Read the repo's durable instruction files before running checks.
3. Infer the likely stack from the repo shape.
4. Run the smallest useful checks first.
5. Write `preflight_report.md` with PASS/WARN/FAIL/SKIP entries.
6. End with a short next-step recommendation:
   - `Start fresh build session`
   - `Fix tooling first`
   - `Auth blocker`
   - `Ready for implementation`

Quality bar:
- This skill exists to prevent long-session context pollution.
- Be strict, concise, and operational.
- Prefer one clear blocker over a long vague checklist.
