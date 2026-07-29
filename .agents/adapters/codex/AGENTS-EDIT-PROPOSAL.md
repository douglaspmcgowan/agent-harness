# Codex `AGENTS.md` edit proposal

This is a proposal for the user-edited file at `C:\Users\dougl\.codex\AGENTS.md`. It does not replace or modify that file.

## 1. Keep in the Codex adapter

Keep only rules that are specific to Codex or to this computer:

- Codex product questions require current official-source research.
- PowerShell and Windows path conventions.
- Codex desktop output-file linking.
- Codex-specific memory location and product hook/config paths.
- Codex browser, preview, and thread behavior.
- Protected local vault paths and current-machine path resolution.

## 2. Move to the canonical shared `AGENTS.md`

Move these cross-agent behaviors to `C:\Users\dougl\.agents\AGENTS.md`, then delete their duplicate prose from the Codex adapter:

- voice and rhetorical-style constraints;
- truth, source verification, and inherited-claim checks;
- secret and authored-file safety;
- direct-question-first communication;
- autonomy and permission preflight;
- simplicity, surgical scope, and goal-driven execution;
- skill discovery and parallelization;
- concise memory-index rules;
- durable correction behavior;
- task-state invariants;
- completion evidence and adversarial verification.

The Codex adapter should contain one line requiring the shared `AGENTS.md`, followed by Codex-only additions.

## 3. Add the existing-system-first rule

Add this sentence to the shared `AGENTS.md` under engineering judgment:

> Before creating a file, module, hook, script, skill, brief, abstraction, or configuration surface, search the current project and shared harness for an existing artifact that can be extended, consolidated, replaced, or removed. Record what was checked. Create a new artifact only when the existing system has no suitable home.

Add this shorter reminder to the Codex adapter:

> Follow the shared existing-system-first rule before creating any artifact.

## 4. Replace the recurring-error section

Replace lines 58–65 with:

> When Douglas requests a recurring behavior change or correction, invoke `/correct`. Reproduce or document the evidence, choose the narrowest durable scope, inspect existing enforcement points, update the smallest suitable rule/skill/test/hook, and verify that a future session receives the correction. Record the correction in the shared append-only feedback log.

The detailed routing procedure belongs in the canonical `/correct` skill.

## 5. Replace task-state prose

Replace lines 132–144 with a compact pointer:

> For multi-step work, reconcile the project `TASK.md` before execution and after every new user instruction. Preserve every requested item, answer or record embedded questions, add only required child tasks, park optional discoveries in `BACKBURNER.md`, and attach verification evidence before marking work complete. Use session-keyed `TASK.<session-id>.md` only when concurrent sessions share a checkout.

The task parser, state transitions, and stop behavior belong in the task-state dispatcher and its tests.

## 6. Merge duplicated sections

- Merge “Surface embedded questions” and “Answer questions when asked.”
- Merge “Adversarially verify” with the completion paragraph under engineering judgment.
- Merge “Check for installed skills” and “Parallelization.”
- Remove the product-local harness table after the global `MAP.md` contains the same paths.
- Keep one Obsidian section and move detailed sync mechanics to a bounded knowledge file.
- Keep one voice-path resolver and remove the repeated path block.

## 7. Correct stale or ambiguous text

- Replace the static knowledge-cutoff sentence with a current-information rule.
- Correct “Codex, Codex” in the product-question section.
- Replace “Parallelize any work by default, if you can” with the eligibility rule: use parallel agents for independent, file-disjoint work; keep coupled work in one owner.
- Replace project `DESIGN.md` references that describe a decision log. `DESIGN.md` carries universal interface rules plus project-specific design rules. Product intent belongs in project `PRODUCT.md` when the repository has a product surface.
- Replace `CURRENT-TASK.md` and `WORK_QUEUE.md` references with `TASK.md` after the migration verifier passes.

## 8. Expected size

The Codex adapter should become a short product-and-machine supplement. Cross-agent behavior should load from one canonical shared file and project-specific behavior from the nearest project contract.

## Acceptance checks

- The shared contract contains every moved invariant exactly once.
- The Codex adapter contains no duplicated shared rule block.
- Existing user-authored Codex-only rules remain present.
- A clean Codex session reports the shared rule source, the nearest project contract, and the Codex supplement.
- The `/correct` trigger and existing-system-first rule are discoverable in a fresh session.
