#!/usr/bin/env node
// Prevents accidental delete/trash operations on the Obsidian vault
const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const toolName = input.tool_name || '';
    const args = JSON.stringify(input.tool_input || {});
    const isDestructive = /delete|remove|trash/i.test(toolName) ||
      /delete|remove|trash/i.test(args);
    if (isDestructive) {
      process.stdout.write(JSON.stringify({
        continue: false,
        stopReason: 'Blocked: Obsidian delete/remove/trash operations require explicit user confirmation.'
      }));
    }
  } catch (_) {}
});

