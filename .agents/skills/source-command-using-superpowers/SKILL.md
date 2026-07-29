---
name: source-command-using-superpowers
description: Compatibility entry for the migrated using-superpowers source command. Use when the user explicitly invokes that command or asks to audit skill-discovery discipline across agent platforms.
---

# Using skills across agent platforms

1. Inspect the skills exposed by the active surface.
2. Select the smallest set whose trigger descriptions cover the request.
3. Load each selected skill completely before taking task actions.
4. Announce the selected skills and their purpose.
5. Follow process skills before implementation skills.
6. Load referenced files only when the selected skill routes to them.
7. Keep product tool names in product adapters. Express the shared workflow through capabilities.
8. When no relevant skill exists, continue with the platform’s ordinary tools and record a reusable gap only after repeated evidence.

User instructions and higher-priority harness rules control conflicts. A skill may add operating discipline within that boundary.

## Platform capability map

- Claude: use its installed command/skill discovery and Claude-owned adapters.
- Codex: use the skills listed for the session and read the selected `SKILL.md`.
- Cursor: use project/global rules and any installed skill integration exposed to the agent.
- Other surfaces: use the product’s documented skill-loading mechanism.

Do not assume a universal `Skill` tool name. Verify the active surface’s capability before referring to one.
