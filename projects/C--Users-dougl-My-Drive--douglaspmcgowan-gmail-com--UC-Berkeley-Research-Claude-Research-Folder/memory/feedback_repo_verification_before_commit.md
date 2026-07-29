---
name: Verify repo before commit or push
description: Before any git commit or push, run `git remote -v` and `git branch --show-current` and quote them back; if user named a specific repo (e.g. "elisa's repo" vs "my fork"), verify the remote URL contains the right username
type: feedback
originSessionId: d88c6f87-874b-4584-b684-02b172df87fd
---

Before any `git commit` or `git push`:

1. Run `git remote -v` and `git branch --show-current` first.
2. Quote both back to the user in chat: "Committing to `<remote-url>` on branch `<branch-name>`."
3. If the user previously specified a target ("commit to elisa's repo" / "my fork" / "the v2 repo"), verify the remote URL contains the right username/repo before proceeding. If it doesn't match, STOP and ask which remote.
4. When working across forked repos with both `origin` and `upstream`, name which remote is the intended target. `origin` is your fork; `upstream` is the source repo. Pushing to `upstream` writes to someone else's repo.

**Why:** In session `d88c6f87` (2026-04-29), Claude was committing to `mccomb-talks` instead of `elisa-lj11/psych-battery`. The user had to ask twice to verify. Same issue recurred 5/3-5/6 in `504d357c`: "I TOLD YOU. PUT IT ON ELISA'S REPO." / "no. put it on a branch ON ELISA'S REPO" / "on my fork of elisa's repo."

**Especially relevant repos** (high collision risk — multiple share the same parent name "psych-battery"):

- `~/psych-battery` → `douglaspmcgowan/psych-battery` (your fork) + upstream `elisa-lj11/psych-battery`
- `~/psych-battery-editorial` → same fork, different branch
- `~/dpm-research-hub` → `douglaspmcgowan/dpm-research-hub`
- `~/Documents/dfm_scraping` → DEPRECATED v1
- `~/Documents/dfm_scraping/dfm-kg-agent-v2` → active v2

**Trigger:** Any tool call invoking `git commit`, `git push`, `gh pr create`, or any branch-creating operation.

**Verification:** User can grep `git log --all --source --remotes` for unintended commits to wrong repos.
