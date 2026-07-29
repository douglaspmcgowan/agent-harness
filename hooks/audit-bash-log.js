#!/usr/bin/env node
// PostToolUse Bash hook: appends a redacted record of every Bash command to an audit log
// for incident review. Never blocks. Credential formats are redacted so the log itself
// cannot become a secret store.

const fs = require('fs');
const path = require('path');
const os = require('os');

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    if (input.tool_name !== 'Bash') return;
    const cmd = (input.tool_input?.command || '').replace(/\r?\n/g, ' ');
    if (!cmd.trim()) return;

    const redact = (s) => s
      .replace(/sk-ant-[A-Za-z0-9_\-]{6,}/g, 'sk-ant-[REDACTED]')
      .replace(/sk-(?:proj-)?[A-Za-z0-9_\-]{12,}/g, 'sk-[REDACTED]')
      .replace(/AKIA[A-Z0-9]{16}/g, 'AKIA[REDACTED]')
      .replace(/gh[pousr]_[A-Za-z0-9_]{20,}/g, 'gh_[REDACTED]')
      .replace(/eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]+/g, 'jwt.[REDACTED]')
      .replace(/((?:API|TOKEN|SECRET|KEY|PASSWORD|AUTH)[A-Z0-9_]*\s*[:=]\s*)["']?[A-Za-z0-9\/+=_\-]{12,}/gi, '$1[REDACTED]');

    const dir = path.join(os.homedir(), '.claude', 'logs');
    fs.mkdirSync(dir, { recursive: true });
    const line = `${new Date().toISOString()}\t${(input.cwd || '').replace(/\t/g, ' ')}\t${redact(cmd)}\n`;
    fs.appendFileSync(path.join(dir, 'bash-audit.log'), line);
  } catch (_) {}
});
