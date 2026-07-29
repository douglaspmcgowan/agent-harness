---
name: cancel-ralph
description: "Cancel the active R14 completion-promise loop (ralph) for this cwd. Standalone command (works regardless of the ralph-loop plugin's enabled state). Use when Douglas says 'cancel ralph', 'stop the loop', '/cancel-ralph'."
---

# /cancel-ralph

1. Resolve `<cwd>` the same way `/ralph-loop` did (the Stop event's reported cwd — usually the workspace
   root for a session launched there).
2. Check `<cwd>/.claude/ralph-loop.local.md`:
   - **Not found** → say "No active ralph loop found at `<cwd>`."
   - **Found** → read its `iteration:` field, delete the file, report "Cancelled ralph loop (was at
     iteration N/max)."
3. **If ralph seems to have stopped firing with no `/cancel-ralph` ever run** (no "iteration N/M" messages
   appearing, replaced by ordinary queue-mode text), it may not be cancelled at all — check `pwd` against the
   workspace root first. The Bash tool's cwd persists across calls; if a `cd` into a subfolder never got undone,
   R14 has been silently looking in the wrong place (see `/ralph-loop`'s "Bash-cwd-drift trap"). `cd` back to
   where the loop file actually lives before concluding it needs re-arming.
4. If you need to halt WITHOUT deleting the loop file (e.g., pausing to hand control back, but may resume
   later), create a session sentinel instead: `.stop-autorun.<sid>` in `taskstate/<project>/` — R3 checks
   this before R14 even looks at the loop file, so it halts cleanly without losing the armed goal. Delete the
   sentinel to resume.
