---
description: Launch a GEN-backed Claude Code session (full agentic CLI on the NASA GEN endpoint, opus-4.8-thinking)
---

# /gen-claude — run a full agentic Claude Code session ON the GEN key

The GEN key isn't just for one-shot `gen.py` calls — you can run an ENTIRE agentic Claude Code session (tools, files,
loops, vision) on the GEN endpoint. The launcher is `~/.claude/gen-claude.sh` (project-agnostic) and the per-project
copy is `…/ai-for-cad/cad-forge/gen-claude.sh`.

**The one thing that makes it work:** the GEN/LiteLLM proxy 400s on Claude Code's beta-only body fields, so the
launcher sets `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`. It derives `ANTHROPIC_BASE_URL` (GEN base minus a trailing
`/v1`) and `ANTHROPIC_API_KEY` from `GEN_BASE_URL`/`GEN_API_KEY` (env → winreg), never printing them, and defaults to
a large `--allowedTools` for autonomous runs.

## How to launch

```bash
# headless one-shot — give it a long prompt and let it run to completion:
/usr/bin/bash ~/.claude/gen-claude.sh -p "<full task prompt>" --add-dir "C:/path/to/project"

# interactive GEN session in a folder:
/usr/bin/bash ~/.claude/gen-claude.sh --add-dir "C:/path/to/project"

# scoped autonomous (override the default allow-list):
/usr/bin/bash ~/.claude/gen-claude.sh -p "<task>" --add-dir "<dir>" --allowedTools "Read Edit Bash"
```

## Rules / gotchas
- **NASA-only, no internet.** GEN has no web access; anything needing WebSearch/WebFetch stays on the main Anthropic session.
- **Verify its output yourself.** A GEN agent can over-claim just like any agent — check its work against ground truth
  (the gate JSON, a render), never the agent's self-report. See [[feedback_verification_discipline]].
- **`--dangerously-skip-permissions` is blocked** by the auto-mode classifier unless a Bash settings rule allows it;
  the baked-in large `--allowedTools` is the clean autonomous-but-scoped path.
- `claude` isn't on the Git Bash PATH — call the launcher with `/usr/bin/bash`, or `claude.exe` by full path.
- Full how-to + the debugging story: `[[reference_api_key_delegation]]`.
