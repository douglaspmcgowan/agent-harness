---
name: skill-audit
description: Audit Agent Skills for trigger quality, progressive disclosure, cross-platform portability, product or model coupling, unsafe writes, broken references, duplication, and project suitability. Use for inventories, pre-install reviews, harness migrations, or grouped remediation Dockets.
---

# Skill audit

Produce one evidence-backed record per discovered `SKILL.md`, then summarize the portfolio by skill. Preserve each canonical skill while recommending thin adapters only where a surface has a real interface difference.

## Audit workflow

1. Establish scope.
   - Resolve every requested skill root.
   - Enumerate all `SKILL.md` files recursively.
   - Use the file path as the identity key. Record a catalog-qualified name when two packages declare the same `name`.
   - Keep generated caches and vendored third-party packages in separate groups.

2. Run the structural pass.
   - On Windows, run `scripts\audit-skills.cmd -RootList "C:\first\skills;C:\second\skills" -Output C:\path\audit.jsonl`.
   - From an existing PowerShell session, use `& scripts\audit-skills.ps1 -Root @('C:\first\skills', 'C:\second\skills') -Output C:\path\audit.jsonl`.
   - The script reports metadata and risk signals without copying skill prose into its output.
   - Reconcile the record count against the filesystem before continuing.

3. Read every selected `SKILL.md` completely.
   - Follow only the references needed to verify a finding.
   - Check referenced scripts and resources for existence.
   - Do not delegate interpretation of the governing skill instructions.

4. Apply the rubric in [audit-schema.md](references/audit-schema.md).
   - Separate deterministic evidence from semantic judgment.
   - Classify each skill as `portable`, `adapter-needed`, `product-owned`, or `broken`.
   - Recommend a provider or model adapter only when tools, invocation syntax, context injection, permissions, or runtime semantics differ.
   - Treat aliases as thin pointers. Avoid copying a canonical workflow into an adapter.
   - Flag broad triggers, duplicated workflows, long frontmatter, large `SKILL.md` bodies, unresolved resources, unsafe overwrite instructions, hardcoded machine paths, and shell assumptions.

5. Write outputs.
   - Emit one JSON object per line using the reference schema.
   - Produce a portfolio summary with totals and highest-severity actions.
   - Group the human review by skill name and retain the source path.
   - When a Docket outbox is requested, use `C:\Users\dougl\.agents\tools\Build-SkillsDocket.cmd` when present. A Docket card is a review surface; the audit JSONL remains the evidence source.

6. Verify.
   - Confirm discovered files equal unique audit paths.
   - Parse every JSONL line.
   - Confirm each cited resource exists or is explicitly marked missing.
   - Inspect a sample from every portability class.
   - State coverage gaps and unavailable product clients.

## Output discipline

- Preserve evidence. Do not silently rewrite audited skills during the audit.
- Keep secret values and credentials out of reports and Docket cards.
- Use stable paths and stable card IDs so reruns can be reconciled.
- Recommend project bindings from demonstrated project needs: technology, recurring workflow, dependency availability, and cloud execution requirements.
- Store canonical shared skills in the shared skill root. Keep product adapters in product-owned configuration and project bindings in the repository.
