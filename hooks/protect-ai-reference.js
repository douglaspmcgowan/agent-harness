#!/usr/bin/env node
// PreToolUse: hard-blocks access to the AI Reference file/folder and 26_Sensitive vault folder.
// Fires on Read/Grep/Glob and all Obsidian MCP tools.
// Exit 2 = block and relay the reason to Claude.

const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
const allText = JSON.stringify(data.tool_input || {});

const BLOCKED = [
  { re: /AI Reference/i, label: "AI Reference (file or folder)" },
  { re: /26_Sensitive/i, label: "26_Sensitive folder" },
  {
    re: /Other People Reference/i,
    label: "Other People Reference (31_Business)",
  },
  {
    re: /Actual Documents[\/\\]Identity/i,
    label: "Identity folder (G:\\My Drive\\Actual Documents\\Identity)",
  },
];

for (const { re, label } of BLOCKED) {
  if (re.test(allText)) {
    console.error(
      `Blocked: "${label}" is off-limits to Claude per user configuration. ` +
        `This file or folder cannot be read, searched, or accessed.`,
    );
    process.exit(2);
  }
}

process.exit(0);
