#!/usr/bin/env node
// Blocks Read and Grep access to the AI Reference file/folder — contains live API keys.
const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const toolInput = input.tool_input || {};
    const candidates = [
      toolInput.file_path || '',
      toolInput.path || '',
      toolInput.pattern || '',
    ];
    if (candidates.some(s => /AI Reference/i.test(s))) {
      process.stdout.write(JSON.stringify({
        continue: false,
        stopReason: 'Blocked: AI Reference path is off-limits (contains live API keys). Access it directly in Obsidian.'
      }));
    }
  } catch (_) {}
});
