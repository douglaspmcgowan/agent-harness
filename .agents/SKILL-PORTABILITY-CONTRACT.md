# Skill portability contract

Last verified: 2026-07-26

## Canonical forms and names

Every artifact has a qualified identity in manifests and audit records. Product-required folder names remain unchanged.

| Form | Qualified identity | Filesystem convention | Purpose |
|---|---|---|
| Canonical skill | `skill:<name>` | `.agents\skills\<name>\SKILL.md` | One authoritative workflow |
| Legacy alias | `alias:<legacy>:<name>` | Existing discoverable folder such as `source-command-<legacy>` | Thin pointer preserving discovery or an old command |
| Product adapter | `adapter:<surface>:<name>` | Product-owned projection, metadata, rule, or launcher | Translates product invocation, tools, paths, permissions, and result handling |
| Project binding | `binding:<project>:<name>` | Entry in `skills-manifest.json` | Declares why the repository needs the canonical skill |
| Provider adapter | `provider:<provider>:<name>` | `references\providers\<provider>.md` | External-service authentication, API, and lifecycle behavior |
| Model-family adapter | `model:<family>:<name>` | `references\models\<family>.md` only when verified | Handles a material model capability or output-contract difference |

Use lowercase ASCII letters, digits, and hyphens. Keep canonical names under 64 characters. Prefer a verb-led name describing the action.

## Product adapters

A product adapter is a small instruction or launcher layer. It is not a second implementation of the workflow.

Adapters may:

- map generic operations to product tool names;
- translate hook payloads and verdict schemas;
- select PowerShell, Windows, or cloud-safe command examples;
- identify a product-owned permission, worktree, notification, or session mechanism;
- point to the canonical skill and required references.

Adapters contain no duplicate canonical procedure. Generated projections carry a source hash in `skill-projection-manifest.json` so drift can be detected.

## Project skill selection

A project receives a skill binding when at least one condition holds:

1. the project has a recurring workflow that general agent reasoning cannot reliably reconstruct;
2. the skill requires project-owned schemas, scripts, templates, or assets;
3. cloud sessions must receive the workflow from the repository;
4. the project has a fragile verifier or safety sequence requiring deterministic guidance.

Global skills remain global when they express Douglas’s personal workflow across many repositories and have no project-owned resources.

The bootstrap creates `skills-manifest.json` with an empty binding list. Agents propose bindings from actual repository evidence such as package files, frameworks, deployment targets, and repeated task history. Each binding records the reason, source, required surfaces, dependencies, and cloud requirement.

A binding uses this shape:

```json
{
  "id": "binding:example-project:deploy-app",
  "skill": "skill:deploy-app",
  "reason": "The repository deploys through Vercel and requires a repeatable preview verification.",
  "source": "global",
  "requiredSurfaces": ["claude", "codex", "cursor", "cloud"],
  "dependencies": ["vercel-cli"],
  "cloudRequired": true
}
```

## Provider and model adapters

Provider adapters are appropriate for meaningful differences such as Bitwarden versus GitHub Actions secrets, Vercel versus local execution, or GitHub versus GitLab review APIs.

Model-family adapters require a verified behavioral need: tool availability, structured-output contract, context limit, or execution environment. Model preference alone does not justify an adapter.

## Skill quality rules

- Keep `SKILL.md` focused on the procedure and under 500 lines.
- Put detailed variants in one-level `references\` files.
- Put deterministic repeated operations in `scripts\`.
- Keep assets in `assets\`.
- Write trigger conditions in the frontmatter description.
- Avoid overlapping broad triggers.
- State inputs, output contract, mutation scope, stop conditions, and verification.
- Name adjacent skills and route between them.
- Prohibit silent overwrites and broad destructive operations.
- Use actual product adapters for tool-name differences.
- Validate the folder and forward-test realistic low-risk cases.

## Audit and Docket

The `skill-audit` skill produces one value-safe finding record per skill. `Build-SkillsDocket.ps1` converts those records into one Docket review card per skill under project `Skills Audit`, grouped into sets by portability status and severity.

The Docket card is a review surface. The JSONL audit is the durable source of evidence. A card decision updates the audit backlog after it is pulled through the Docket protocol.
