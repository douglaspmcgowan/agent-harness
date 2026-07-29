# Feedback log

Append-only, value-free correction records. Supersede or retire an entry by appending a new record that references its ID.

- 2026-07-28 | communication/name-frequency | Douglas asked agents to stop beginning every message with his name. Use his name sparingly, when it adds clarity or warmth; routine updates should begin with the result or action.
- 2026-07-28 | process-safety/codex-renderers | An agent stopped low-memory `ChatGPT.exe` renderer children under the active `OpenAI.Codex` host, which closed the app. Renderer IDs and resource use do not identify task ownership. Never terminate individual renderer or utility children in the active Codex tree; limit cleanup to proven detached CLI/helpers, and require explicit confirmation before a whole-app restart.
- 2026-07-28 | auth-context/github-cli | Repeated GitHub device-login prompts were triggered by trusting `gh auth status` from the sandbox context. The interactive Windows user was already authenticated through the keyring. Verify GitHub status under the interactive user's context before reauthentication and never overlap device flows.


## feedback-20260726-portable-baseline-and-open-questions

timestamp: 2026-07-27T00:51:31.3347362Z
incident: The repository baseline omitted several cross-project judgment rules and open questions were too easy to lose during long turns.
consequence:
rootCauseStatus: reproduced
scope:
  - shared
  - project
surfaces:
enforcement:
  - rule
  - skill
  - test
  - brief
evidence:
  - C:\Users\dougl\.agents\templates\AGENTS.md
  - C:\Users\dougl\.codex\AGENTS.md
  - user annotation 2026-07-26
artifacts:
  - C:\Users\dougl\.agents\PORTABLE-PRINCIPLES.md
  - C:\Users\dougl\.agents\skills\feedback\SKILL.md
verification: Feedback skill test plus project baseline verifier
owner: Douglas
status: enforced
reviewTrigger: next material global-rule change

## feedback-20260727-preview-before-handoff

timestamp: 2026-07-27T20:11:49.1180995Z
incident: An undeployed browser-visible 168 Audit change was handed off without an open preview URL.
consequence: Douglas could not review the completed local interface in the browser.
rootCauseStatus: reproduced
scope:
  - shared
  - platform
surfaces:
  - Codex global harness
enforcement:
  - rule
  - verifier
evidence:
  - user correction 2026-07-27
  - C:\Users\dougl\projects\168-audit\server.js
artifacts:
  - C:\Users\dougl\.codex\AGENTS.md
  - C:\Users\dougl\.agents\feedback\FEEDBACK-LOG.md
verification: Confirm the global rule text and open a local preview URL before handoff.
owner: Douglas
status: enforced
reviewTrigger: next undeployed browser-visible handoff

## feedback-20260727-exact-action-handoffs

timestamp: 2026-07-27T20:52:43.3242176Z
incident: A completion or blocked-goal handoff can leave Douglas to reconstruct required operational steps.
consequence: Required setup may remain incomplete or be performed incorrectly when the handoff lacks exact locations, fields, formats, and return confirmation.
rootCauseStatus: supported
scope:
  - shared
surfaces:
  - claude
  - codex
  - cursor
enforcement:
  - rule
  - verifier
  - brief
evidence:
  - Codex task 019fa0dd-7444-7173-88b2-f0db502d9d18 user instruction dated 2026-07-27
artifacts:
  - C:\Users\dougl\.agents\PORTABLE-PRINCIPLES.md
  - C:\Users\dougl\.agents\CROSS-AGENT-CONTRACT.md
  - C:\Users\dougl\.agents\tools\Test-HarnessSetup.ps1
  - C:\Users\dougl\.agents\human-readable\17-FEEDBACK-ROUTING-AND-CORRECTIONS.md
verification: Test-HarnessSetup.cmd checks the portable and shared contract wording; adversarial review covers complete, blocked, and no-action endings.
owner: Douglas
status: enforced
reviewTrigger: Any report that Douglas could not locate or execute a required next step.

## feedback-20260727-standing-subagent-approval

timestamp: 2026-07-27T22:12:44.9953031Z
incident: Douglas asked that future eligible work default to sub-agent delegation without another approval prompt.
consequence: Repeated approval prompts slow independent review and other eligible delegated work.
rootCauseStatus: supported
scope:
  - shared
  - platform
surfaces:
  - claude
  - codex
  - cursor
enforcement:
  - rule
  - test
  - brief
evidence:
  - Codex task 019fa0dd-7444-7173-88b2-f0db502d9d18 user instruction dated 2026-07-27
artifacts:
  - C:\Users\dougl\.agents\PORTABLE-PRINCIPLES.md
  - C:\Users\dougl\.agents\CROSS-AGENT-CONTRACT.md
  - C:\Users\dougl\.agents\tools\Test-HarnessSetup.ps1
  - C:\Users\dougl\.agents\human-readable\17-FEEDBACK-ROUTING-AND-CORRECTIONS.md
  - C:\Users\dougl\.agents\human-readable\CHANGELOG.md
  - C:\Users\dougl\.agents\human-readable\setup-stamp.json
verification: Update-HarnessSetupStamp.cmd refreshed 94 hashes; Test-HarnessSetup.cmd passed all checks including the new contract assertions.
owner: Douglas
status: enforced
reviewTrigger: Any future eligible task that pauses solely to request sub-agent permission.

## premature-completion-under-parallelization-20260729

timestamp: 2026-07-29T05:25:16.0806761Z
incident: A completion-style handoff occurred while actionable queue items and independent workstreams remained, requiring Douglas to restate that work should continue and be parallelized.
consequence: RAM diagnostics, Bitwarden setup, Drive narrowing, governance repairs, and final Codex reconciliation remained unfinished across handoffs.
rootCauseStatus: hypothesis
scope:
  - shared
  - project
surfaces:
  - cross-agent task intake
  - queue-driven execution
  - parallel-agent dispatch
  - verification before completion
enforcement:
  - skill
  - verifier
  - test
  - backlog
evidence:
  - C:\Users\dougl\projects\general-claude\CURRENT-TASK.md â€” remaining workstreams
  - C:\Users\dougl\projects\general-claude\WORK_QUEUE.md â€” actionable and in-progress markers
  - Current user correction requesting continued parallel execution
artifacts:
  - C:\Users\dougl\.agents\feedback\FEEDBACK-LOG.md
  - C:\Users\dougl\projects\general-claude\WORK_QUEUE.md
  - C:\Users\dougl\projects\general-claude\VERIFY.md
verification: Record appended; queue reseeded and three independent workers dispatched. Mechanical completion fixtures remain pending.
owner: general-ai harness agent
status: recorded
reviewTrigger: Review after the next three multi-stream tasks or immediately if a completion handoff appears while actionable queue markers remain.

## bitwarden-template-login-property-20260729

timestamp: 2026-07-29T16:41:04.9015431Z
incident: Bitwarden scaffold creation failed after interactive authentication because creator assembly assigned a Login object through a property absent from the base item template.
consequence: Interactive authentication completed but scaffold creation stopped before any item receipt was written, forcing avoidable repeated setup effort.
rootCauseStatus: reproduced
artifactDecision: extend
existingSearch:
  - New-BitwardenProjectScaffolds.ps1 creator owner
  - New-BitwardenProjectScaffolds.Tests.ps1 plan-only coverage
  - Run-BitwardenScaffoldInteractive.ps1 authentication wrapper
  - Run-BitwardenScaffoldInteractive.Tests.ps1 wrapper coverage
scope:
  - shared
  - platform
  - human
surfaces:
  - Bitwarden Password Manager CLI scaffold creator
  - Interactive Capsule setup wrapper
enforcement:
  - test
evidence:
  - Production exception at New-BitwardenProjectScaffolds.ps1 login assignment
  - Value-free create-mode mock fixture failed at the same assignment before the fix
artifacts:
  - .agents/tools/New-BitwardenProjectScaffolds.ps1
  - .agents/tools/New-BitwardenProjectScaffolds.Tests.ps1
verification: Create-mode scaffold regression and interactive wrapper suite pass; CLI remains locked and receipt is absent after the failed run.
owner: agent-harness
status: enforced
reviewTrigger: Bitwarden CLI template schema or scaffold creator changes
