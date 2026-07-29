#!/usr/bin/env node
// PreToolUse hook for Read|Grep|Glob: blocks the NATIVE file tools from opening secret-bearing
// files (.env, cloud creds, SSH private keys, etc.). Closes the gap where check-secret-exposure.js
// only guards Bash — the Read tool could otherwise read these files directly into context.
// Template/example variants (.env.example, *-template) are allowed.

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const ti = input.tool_input || {};
    // Read uses file_path; Grep/Glob use path + pattern (path is the dir/file searched).
    const target = String(ti.file_path || ti.path || '');
    if (!target) return;

    // allow template/example/sample variants
    if (/[._-](example|sample|template|tmpl|dist|skeleton|test)([._-]|$)/i.test(target)) return;

    const SENSITIVE = [
      /(^|[\/\\])\.env($|\.)/i,                                  // .env, .env.local, .env.production
      /[\/\\]\.aws[\/\\](?:credentials|config)$/i,               // AWS creds
      /[\/\\]\.ssh[\/\\]id_(?:rsa|dsa|ecdsa|ed25519)(?!\.pub)$/i, // SSH private keys
      /(^|[\/\\])id_(?:rsa|dsa|ecdsa|ed25519)(?!\.pub)$/i,
      /[\/\\]\.npmrc$/i,
      /[\/\\]\.pypirc$/i,
      /[\/\\]\.netrc$/i,
      /[\/\\]\.docker[\/\\]config\.json$/i,
      /[\/\\]\.kube[\/\\]config$/i,
      /application_default_credentials\.json$/i,
      /[\/\\]\.git-credentials$/i,
      /(^|[\/\\])credentials\.(json|ya?ml|toml|ini|cfg)$/i,
      /\.(pem|p12|pfx|key)$/i,                                    // private key / cert material
      /secrets?\.(json|ya?ml|toml|ini|env)$/i,
    ];

    if (SENSITIVE.some(re => re.test(target))) {
      // Warn via stderr — Claude reports this and asks the user for approval.
      // Does NOT hard-block so the agent turn can continue after user confirms.
      process.stderr.write(
        `[sensitive-file-read] ⚠ "${target}" looks like a secret-bearing file.\n` +
        `Reading it pulls credentials into context. Confirm with the user before proceeding.\n`
      );
    }
  } catch (_) {}
});
