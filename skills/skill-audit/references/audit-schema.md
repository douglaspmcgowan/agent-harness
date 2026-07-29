# Skill-audit rubric and record schema

## Forms

| Form | Meaning | Naming |
|---|---|---|
| Canonical skill | Provider-neutral workflow and durable guidance | `<capability>` |
| Compatibility alias | Thin pointer retained for discovery or an old name | `<capability>-pointer` or documented legacy name |
| Product adapter | Invocation, tool, permission, or context-loading details for one surface | `<capability>.<surface>.adapter` in manifests; keep product-owned files in that product's config |
| Project binding | Repository declaration selecting a canonical skill and project constraints | `<repo>/.agents/skills-manifest.json` entry |
| Generated cache | Product-created installed copy or index | Product-owned name; never edit as canonical source |

Use a catalog-qualified display name such as `package:skill` when duplicate frontmatter names exist.

## Portability classes

- `portable`: the workflow runs across supported agents with ordinary capability substitution.
- `adapter-needed`: the core workflow is reusable and one or more interfaces require thin translation.
- `product-owned`: the behavior is meaningful only inside one product.
- `broken`: required resources, entry points, or instructions cannot be resolved.

Apply this precedence:

1. `broken` when a required entry point or resource cannot resolve;
2. `product-owned` when the complete workflow has meaning on one surface;
3. `adapter-needed` when a reusable core remains after translating interfaces;
4. `portable` when ordinary capability substitution is sufficient.

## Severity

- `high`: unsafe writes, secret exposure, broken load-bearing workflow, or misleading duplicated authority.
- `medium`: portability failure, shell mismatch, unresolved optional dependency, excessive bloat, or strong overlap.
- `low`: cleanup, naming, or documentation improvement.
- `none`: no material finding in the reviewed scope.

Record the highest supported severity. Several medium findings remain `medium` unless their interaction creates a demonstrated high-impact failure. Conditional overwrite language is medium; an executable unguarded overwrite of authored or sensitive data is high.

## Frontmatter profile

For a canonical shared skill, `frontmatter_ok` means parseable YAML containing exactly `name` and `description`, with a lowercase-hyphen name matching the package folder. Product-specific fields belong in product metadata such as `agents/openai.yaml` or in a surface projection. When auditing a deliberately product-owned package, record extra supported fields in the finding and classify them according to that product’s documented schema.

## JSONL record

Each line must be one JSON object:

```json
{
  "name": "skill-name",
  "catalog_name": "optional-qualified-name",
  "path": "absolute path to SKILL.md",
  "line_count": 120,
  "frontmatter_ok": true,
  "trigger_quality": "clear",
  "portable_status": "portable",
  "product_dependencies": [],
  "model_dependencies": [],
  "hardcoded_paths": [],
  "shell_mismatches": [],
  "overlaps": [],
  "bloat_findings": [],
  "unsafe_or_overwrite_findings": [],
  "missing_resources": [],
  "recommended_actions": [],
  "severity": "none"
}
```

Arrays contain concise findings rather than copied source passages. `path` is the record identity.

## Semantic checks

Ask:

1. Does the description say what the skill does and when it should trigger?
2. Can a capable agent follow the workflow without product-specific assumptions?
3. Does every adapter translate a concrete interface difference?
4. Could progressive disclosure move catalogs, examples, or reference material out of `SKILL.md`?
5. Do write instructions preserve existing authored work and respect repository boundaries?
6. Are model names used for a necessary capability distinction?
7. Is another skill already authoritative for the same workflow?
8. Do referenced scripts, templates, and documents resolve from the skill directory?
9. Can a cloud agent start from repository-visible instructions without relying on machine-global state?
10. Does an output path already exist, and does the workflow define backup, versioning, append, or explicit replacement behavior?
