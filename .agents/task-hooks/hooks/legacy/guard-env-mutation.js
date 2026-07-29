#!/usr/bin/env node
// guard-env-mutation.js — PreToolUse(Bash) guard: gate environment-mutating commands.
//
// WHY: on 2026-06-26 a background subagent tried to repair/reinstall VTK with pip; the operation was
// interrupted partway and left the install half-written (vtk.libs 81/153 DLLs, vtkfmt gone), which broke
// CadQuery and the whole gate. Env changes ARE sometimes the right fix — but only when DELIBERATE:
// checkpoint first, run from the main session (not unattended), finish it, verify imports after.
//
// So this BLOCKS env mutation by default and offers an explicit opt-in: prefix the command with
// ALLOW_ENV_MUTATION=1 to proceed (a conscious choice a runaway agent won't make by accident).
// Exit 2 = block (stderr reason is relayed to Claude); exit 0 = allow.
const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
if (data.tool_name && data.tool_name !== "Bash" && data.tool_name !== "PowerShell") process.exit(0);
const cmd = ((data.tool_input && data.tool_input.command) || "").toString();

if (/\bALLOW_ENV_MUTATION=1\b/.test(cmd)) process.exit(0); // explicit, deliberate opt-in

const mutations = [
  { p: /\bpip[0-9.]*\s+(install|uninstall)\b/, l: "pip install/uninstall" },
  { p: /\bpython[0-9.]*\s+-m\s+pip\s+(install|uninstall)\b/, l: "python -m pip install/uninstall" },
  { p: /\b(conda|mamba)\s+(install|remove|uninstall|update|upgrade)\b/, l: "conda/mamba env change" },
  { p: /\bscoop\s+(install|uninstall|update)\b/, l: "scoop install/uninstall" },
  { p: /\bnpm\s+(install|uninstall|i|rm|ci)\b[^|;&]*?\s(?:-g|--global)\b/, l: "npm global install" },
  { p: /\b(pipx|uv)\s+(install|uninstall|remove)\b/, l: "pipx/uv install" },
  { p: /\bpoetry\s+(add|remove)\b/, l: "poetry add/remove" },
];
for (const { p, l } of mutations) {
  if (p.test(cmd)) {
    console.error(
      `Blocked environment mutation (${l}): ${cmd.slice(0, 120)}\n` +
        `Shared Python/Node env changes must be DELIBERATE — an interrupted pip reinstall gutted the VTK install ` +
        `and broke the toolchain (2026-06-26). If this is intended:\n` +
        `  1) git-commit a checkpoint first,\n` +
        `  2) run it in the MAIN session (not an unattended subagent),\n` +
        `  3) re-run prefixed with ALLOW_ENV_MUTATION=1 to proceed,\n` +
        `  4) verify imports afterward.`,
    );
    process.exit(2);
  }
}
process.exit(0);
