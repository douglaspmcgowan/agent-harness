---
name: Verify repo before any commit or push
description: Run git remote -v and check branch before any git commit or push; read repo-map.md to confirm the right repo
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
Before any `git commit` or `git push`: (1) run `git remote -v`, (2) confirm branch, (3) read `/g/My Drive/UC Berkeley/Research/Claude Research Folder/repo-map.md` to verify local path maps to the intended GitHub repo.

**Why:** Commits to the wrong repo or branch have happened and are hard to undo cleanly.

**How to apply:** Make this a reflex before every commit. The repo-map is the authoritative source — trust it over memory.
