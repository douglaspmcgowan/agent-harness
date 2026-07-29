#!/usr/bin/env node
// guard-bulk-delete.js — PreToolUse(Bash) guard: block BULK / irrecoverable file deletion.
//
// WHY: on 2026-06-26 a background subagent removed ~50 tracked source files from the working tree
// (incl. bill_of_joints.py, build_sections2.py). They were recoverable only because git still had them.
// Moving/renaming and single-file deletes are LEGITIMATE (refactoring needs them) and stay allowed — this
// only gates the mass/recursive destructive patterns that wipe many files at once.
//
// Override (deliberate, after a checkpoint): prefix the command with ALLOW_BULK_DELETE=1.
// Exit 2 = block (stderr reason relayed to Claude); exit 0 = allow.
const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
if (data.tool_name && data.tool_name !== "Bash" && data.tool_name !== "PowerShell") process.exit(0);
const cmd = ((data.tool_input && data.tool_input.command) || "").toString();

if (/\bALLOW_BULK_DELETE=1\b/.test(cmd)) process.exit(0); // explicit, deliberate opt-in

const bulk = [
  { p: /\bgit\s+rm\b/, l: "git rm (removes tracked files)" },
  { p: /\brm\s+(?:-[a-z]*\s+)*[^|;&]*\*/, l: "rm with a wildcard (mass delete)" },
  { p: /\brm\s+-[a-z]*r[a-z]*\b/, l: "rm -r / -rf (recursive delete)" },
  { p: /\bRemove-Item\b[^|;&]*-Recurse/i, l: "Remove-Item -Recurse" },
  { p: /\bRemove-Item\b[^|;&]*-Force/i, l: "Remove-Item -Force" },
  { p: /\bfind\b[^|]*\s-delete\b/, l: "find -delete" },
  { p: /\bfind\b[^|]*-exec\s+rm\b/, l: "find -exec rm" },
  { p: /\bxargs\b[^|]*\brm\b/, l: "xargs rm (bulk delete)" },
];
for (const { p, l } of bulk) {
  if (p.test(cmd)) {
    console.error(
      `Blocked bulk/irrecoverable delete (${l}): ${cmd.slice(0, 120)}\n` +
        `A subagent mass-deleted ~50 source files this way (2026-06-26). Single moves/renames and single-file ` +
        `deletes are fine; mass/recursive deletion must be DELIBERATE. If intended:\n` +
        `  1) make sure git has a clean checkpoint of these files (git commit),\n` +
        `  2) re-run prefixed with ALLOW_BULK_DELETE=1 to proceed.`,
    );
    process.exit(2);
  }
}
process.exit(0);
