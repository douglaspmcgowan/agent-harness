---
name: project-security-pack
description: "AI Security Pack is installed on this desktop; Doug's personal check-secret-exposure & block-dangerous-bash hooks are intentional and must not be overwritten by the NASA pack versions."
metadata:
  node_type: memory
  type: project
  originSessionId: 94fbba7f-b26f-468b-b5f8-3470f9f8eb79
---

AI Security Pack (from `…/Claude Research Folder/NASA uploads/AI Security Pack`) is installed and verified on this desktop as of 2026-05-28: 7 NASA hooks active in `~/.claude/hooks/` and registered in `~/.claude/settings.json` (block-egress-exfil, block-nasa-web-egress, block-sensitive-file-read, protect-security-config, scan-write-for-secrets, scan-output-for-secrets, audit-bash-log), plus gitleaks 8.30.1 + global `~/.git-hooks/pre-commit`.

**Why:** Doug already had his OWN git-tracked, modern "ask"-style `check-secret-exposure.js` and exit-2 `block-dangerous-bash.js` on this machine — better and newer than the NASA pack's hard-block versions. The NASA `install.js` blindly copies all hooks, which would clobber them.

**How to apply:** If asked to (re)install the NASA pack here, do NOT overwrite `check-secret-exposure.js` or `block-dangerous-bash.js` — his personal versions are the intended ones (verify via `git -C ~/.claude status`). The NASA `test-secret-hooks.js` tests the NASA hard-block variant, so its FN counts are NOT meaningful against Doug's ask-style hook; don't chase FP=0/FN=0 on it here.
