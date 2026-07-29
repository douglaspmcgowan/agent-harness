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
  const patterns = [
    /\b(?:echo|write-output)\s+["']?\$env:[A-Z_]*(?:KEY|SECRET|TOKEN|PASSWORD|AUTH|CREDENTIAL)/i,
    /\becho\s+\$[A-Z_]*(?:KEY|SECRET|TOKEN|PASSWORD|AUTH|CREDENTIAL)/i,
    /\b(?:cat|type|get-content)\b[^\r\n|;]*[\s"'\\/]\.env(?:\b|$)/i,
    /\bprintenv\s+[A-Z_]*(?:KEY|SECRET|TOKEN|PASSWORD|AUTH|CREDENTIAL)/i,
    /\b(?:env|set|get-childitem\s+env:|dir\s+env:)\b.*\|\s*(?:grep|findstr|select-string)/i,
    /process\.env\.[A-Z_]*(?:KEY|SECRET|TOKEN|PASSWORD|AUTH|CREDENTIAL)/i,
    /\bbw\s+(?:list|export|get)\b/i,
  ];

  if (patterns.some(pattern => pattern.test(command))) {
    deny('Blocked: this command may expose credentials or vault data.');
    return;
  }

  process.exit(0);
});
