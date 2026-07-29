---
name: feedback
description: "Turn Douglas's corrections into durable scoped prevention. Use when Douglas reports an agent mistake, says 'never do that again,' asks to remember feedback, or wants rules, hooks, tests, verifiers, permissions, memories, skills, or adapters updated from observed behavior."
---

# Feedback

Convert a correction into evidence, routing, one or more enforcement artifacts, and proof that a future session can receive the lesson.

## What this is for

Use this for observed mistakes and explicit corrections. Use ordinary task state for unfinished work, `STATUS.md` or `MAP.md` for project facts, and a Setup brief for explanation without an enforcement request.

## Procedure

1. Answer Douglas's correction directly and stop the failing path.
2. Preserve value-free evidence. Record file/test/screenshot/transcript locations without copying credentials, sensitive content, or private data.
3. Classify root-cause status as `hypothesis`, `supported`, or `reproduced`. Reproduce safely when the claimed cause will enter durable memory or drive a load-bearing guard.
4. Choose every supported scope:
   - `path`
   - `project`
   - `shared`
   - `platform`
   - `provider-model`
   - `human`
5. Choose every useful enforcement mechanism. The list is deliberately non-exclusive:
   - `rule`
   - `skill`
   - `memory`
   - `verifier`
   - `hook`
   - `permission`
   - `test`
   - `brief`
   - `backlog`
6. Prefer the narrowest proven scope. A safety, privacy, data-loss, or high-cost incident may receive immediate deterministic enforcement after reproduction. Promote ordinary preferences to shared scope after cross-project evidence.
7. Append the record with `scripts/Record-Feedback.ps1`. Use the repository log for project/path feedback and the shared log for cross-project/platform/provider feedback.
8. Implement every selected enforcement artifact that is authorized and safe. A correction is durable when a future session receives or mechanically encounters the artifact without this chat.
9. Verify each mechanism independently, then run the assembled repository or harness verifier.
10. Update `MAP.md` for new project artifacts. Update the Setup brief, changelog, and integrity stamp for material shared-harness changes.
11. Report scope, mechanisms, artifact paths, proof, unresolved cause, and review trigger. Repeat every open question at the end of the turn.

## Record contract

Each append-only entry contains:

- stable ID and UTC timestamp;
- value-free incident summary and evidence references;
- consequence and root-cause status;
- one or more scopes and surfaces;
- `enforcement`, as a YAML list containing one or more mechanisms;
- artifact paths, verification, status, owner, and review trigger.

Never rewrite an old entry to hide history. Append a superseding or retirement entry that references the earlier ID.

## Safety

- Keep secrets and protected content out of records.
- Label a plausible cause as a hypothesis until reproduced.
- Do not broaden a project correction into a global rule from one ordinary occurrence.
- Keep platform mechanics in thin adapters and shared behavior in the portable contract or skill.
- Make reversible changes and preserve existing project-specific instructions.

## Final report

State what was verified this pass and what remains. Include the full paths of all created or updated artifacts and repeat open questions at the end.
