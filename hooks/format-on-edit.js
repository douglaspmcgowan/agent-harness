#!/usr/bin/env node
// Auto-formats JS/TS/JSON/CSS/HTML files after Write or Edit using prettier (if available)
const { execSync } = require('child_process');
const path = require('path');

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const filePath = input.tool_input?.file_path || input.tool_response?.filePath || '';
    if (!filePath) return;

    const ext = path.extname(filePath).toLowerCase();
    const formattable = ['.js', '.jsx', '.ts', '.tsx', '.json', '.css', '.html', '.md'];
    if (!formattable.includes(ext)) return;

    // Try local prettier first, then global
    const quoted = `"${filePath.replace(/"/g, '\\"')}"`;
    try {
      execSync(`npx --no-install prettier --write ${quoted} 2>/dev/null`, { timeout: 15000 });
    } catch (_) {
      try {
        execSync(`prettier --write ${quoted} 2>/dev/null`, { timeout: 15000 });
      } catch (_) {
        // prettier not available â€” skip silently
      }
    }
  } catch (_) {}
});

