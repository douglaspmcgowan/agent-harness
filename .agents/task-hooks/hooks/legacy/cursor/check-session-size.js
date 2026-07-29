#!/usr/bin/env node
// Stop hook: warn if the current session transcript is approaching a large size
const fs = require('fs');
const path = require('path');
const os = require('os');

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString() || '{}');
    const sessionId = input.session_id;
    if (!sessionId) return;

    const home = process.env.USERPROFILE || process.env.HOME || '';
    const projectsDir = path.join(home, '.claude', 'projects');

    // Find the session file across all project directories
    let sessionFile = null;
    if (fs.existsSync(projectsDir)) {
      for (const proj of fs.readdirSync(projectsDir)) {
        const candidate = path.join(projectsDir, proj, `${sessionId}.jsonl`);
        if (fs.existsSync(candidate)) { sessionFile = candidate; break; }
      }
    }

    if (!sessionFile) return;
    const stats = fs.statSync(sessionFile);
    const sizeMB = stats.size / (1024 * 1024);

    // Warn at 5 MB (~approaching large context)
    if (sizeMB > 5) {
      process.stdout.write(JSON.stringify({
        systemMessage: `Session transcript is ${sizeMB.toFixed(1)} MB. Consider running session rollover soon.`
      }));
    }
  } catch (_) {}
});
