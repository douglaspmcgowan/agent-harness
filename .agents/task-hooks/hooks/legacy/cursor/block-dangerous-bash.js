#!/usr/bin/env node
'use strict';

const chunks = [];
let bytes = 0;
const maxBytes = 1024 * 1024;

function deny(reason) {
  const body = JSON.stringify({
    permission: 'deny',
    user_message: reason,
    agent_message: reason,
  });
  process.stdout.write(body, () => setTimeout(() => process.exit(2), 75));
}

process.stdin.on('data', chunk => {
  bytes += chunk.length;
  if (bytes > maxBytes) deny('Blocked: hook input exceeded the safety limit.');
  chunks.push(chunk);
});

process.stdin.on('end', () => {
  let input;
  try {
    input = JSON.parse(Buffer.concat(chunks).toString());
  } catch (_) {
    // Cursor sometimes sends non-JSON hook payloads; do not block all Shell calls.
    process.exit(0);
  }

  const command = String((input.tool_input && input.tool_input.command) || input.command || '');
  const rules = [
    { pattern: /\brm\s+-[a-z]*r[a-z]*f\s+(?:\/|~)(?:\s|$)/i, label: 'recursive delete of root or home' },
    { pattern: /\bremove-item\b[^\r\n]*(?:-recurse[^\r\n]*-force|-force[^\r\n]*-recurse)[^\r\n]*(?:\$home|~|c:\\users\\[^\\\s]+)(?:\\|\s|$)/i, label: 'recursive delete of a user profile' },
    { pattern: /\b(?:rmdir|rd)\s+\/s\b[^\r\n]*(?:c:\\|%userprofile%)/i, label: 'recursive delete of a broad Windows path' },
    { pattern: /\bgit\s+push\b[^\r\n]*(?:--force|-f)(?:\s|$)/i, label: 'force push' },
    { pattern: /\bgit\s+reset\s+--hard\b/i, label: 'hard reset' },
    { pattern: /\bgit\s+clean\s+-[a-z]*f/i, label: 'forced Git clean' },
    { pattern: /\bgit\s+checkout\s+--\s/i, label: 'discarding checkout' },
    { pattern: /\bgit\s+branch\s+-D\s/i, label: 'forced branch deletion' },
    { pattern: /\bDROP\s+TABLE\b/i, label: 'DROP TABLE' },
    { pattern: /\bTRUNCATE\s+TABLE\b/i, label: 'TRUNCATE TABLE' },
  ];

  const matched = rules.find(rule => rule.pattern.test(command));
  if (matched) {
    deny(`Blocked dangerous command: ${matched.label}.`);
    return;
  }

  process.exit(0);
});
