#!/usr/bin/env node
// PreToolUse Write|Edit|NotebookEdit hook: blocks WRITING a hardcoded credential into a file,
// so a real secret can't get baked into source and committed. Mirrors the output scanner's
// high-precision FORMAT patterns. Placeholder/example values are allowed.

const path = require('path');
const { allowsSecret } = require(path.join(__dirname, 'allow-tags'));

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const ti = input.tool_input || {};
    const content = [ti.content, ti.new_string, ti.new_source].filter(Boolean).join('\n');
    if (!content) return;

    // Escape hatch: [allow-secret] / [allow-all] in the user's current prompt lets this one write
    // through (e.g. intentionally committing a test fixture) instead of disabling the whole hook
    // (see allow-tags.js). Fails closed — no tag (or any transcript-read error) keeps the block.
    if (allowsSecret(input)) return;

    const FORMATS = [
      /sk-ant-[A-Za-z0-9_\-]{20,}/,
      /sk-(?:proj-)?[A-Za-z0-9_\-]{20,}/,
      /AKIA[A-Z0-9]{16}/,
      /gh[pousr]_[A-Za-z0-9_]{36,}/,
      /xox[baprs]-[A-Za-z0-9\-]{10,}/,
      /AIza[A-Za-z0-9_\-]{35}/,
      /eyJ[A-Za-z0-9_\-]{20,}\.eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{10,}/,
      /-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----[\s\S]{40,}/,
    ];

    const isPlaceholder = (s) =>
      /EXAMPLE|PLACEHOLDER|YOUR[_-]?(?:KEY|TOKEN|SECRET|API)|DUMMY|FAKE|REDACTED|XXXX|SAMPLE|TEST_?KEY|CHANGEME|\.\.\.|<[^>]+>/i.test(s)
      || /(.)\1{15,}/.test(s);                              // long run of one char (AAAA…, 0000…)

    for (const re of FORMATS) {
      const m = content.match(re);
      if (m && !isPlaceholder(m[0])) {
        return process.stdout.write(JSON.stringify({
          continue: false,
          stopReason: 'Blocked: the content being written contains what looks like a hardcoded credential. Use an environment variable or secret manager instead of embedding the key in a file.'
        }));
      }
    }
  } catch (_) {}
});
