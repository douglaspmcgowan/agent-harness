#!/usr/bin/env node
'use strict';
// dep-audit-gate.js — PreToolUse (Bash|PowerShell). WARN-ONLY opt-in gate.
// Catches HALLUCINATED / SLOPSQUATTED package names before install: when a command installs Python or
// JS packages, each new package name is checked for existence on the real registry (PyPI / npm). A name
// that returns 404 is almost always an AI hallucination or a typo-squat — warned, never blocked.
//
// OPT-IN: no-op unless `.claude/gates.json` (at or above cwd) has "dep_audit": true. See gates-config.js.
// FAIL-OPEN: any error, timeout, or network failure => allow silently (registry unreachable must never block work).
// WARN-ONLY: surfaces a systemMessage; the install proceeds regardless (block phase is a later tuning step).
const https = require('https');
const path = require('path');
const { gateOn } = require(path.join(__dirname, 'gates-config.js'));

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  let input;
  try { input = JSON.parse(Buffer.concat(chunks).toString()); } catch (_) { return; }
  try {
    const cwd = (input && input.cwd) || process.cwd();
    if (!gateOn(cwd, 'dep_audit')) return;                      // not opted in => no-op
    const cmd = (input.tool_input && input.tool_input.command || '').replace(/\r?\n/g, ' ');
    if (!cmd.trim()) return;

    const pkgs = extractPackages(cmd);                          // [{name, registry}]
    if (!pkgs.length) return;

    // Dedup, cap to keep the hook fast/bounded.
    const seen = new Set(), list = [];
    for (const p of pkgs) { const k = p.registry + ':' + p.name.toLowerCase(); if (!seen.has(k)) { seen.add(k); list.push(p); } }
    const capped = list.slice(0, 12);

    Promise.all(capped.map(existsOnRegistry)).then(results => {
      const missing = capped.filter((p, i) => results[i] === false).map(p => `${p.name} (${p.registry})`);
      if (missing.length) {
        process.stdout.write(JSON.stringify({
          continue: true,
          systemMessage: `⚠ dep-audit gate: ${missing.length} package name(s) NOT found on their registry: ${missing.join(', ')}. ` +
            `A missing name is often a hallucinated or typo-squatted package (RCE vector). Verify the exact name before installing.`,
        }));
      }
    }).catch(() => {});                                         // fail open
  } catch (_) {}                                               // fail open
});

// Parse `pip install`, `pip3 install`, `python -m pip install`, `uv pip install`, `uv add`,
// `npm install/i/add`, `pnpm add`, `yarn add` and return the concrete package names (not flags/urls/paths).
function extractPackages(cmd) {
  const out = [];
  const isPy = /\b(?:pip3?|python3?\s+-m\s+pip|uv\s+pip)\s+install\b/i.test(cmd) || /\buv\s+add\b/i.test(cmd);
  const isJs = /\b(?:npm\s+(?:install|i|add)|pnpm\s+add|yarn\s+add)\b/i.test(cmd);
  if (!isPy && !isJs) return out;

  // Take tokens after the install verb on each install segment (split on shell separators).
  for (const seg of cmd.split(/[;&|]{1,2}/)) {
    const m = seg.match(/\b(?:pip3?|python3?\s+-m\s+pip|uv\s+pip)\s+install\b|\buv\s+add\b|\b(?:npm\s+(?:install|i|add)|pnpm\s+add|yarn\s+add)\b/i);
    if (!m) continue;
    const reg = /npm|pnpm|yarn/i.test(m[0]) ? 'npm' : 'pypi';
    const rest = seg.slice(m.index + m[0].length).trim().split(/\s+/);
    for (const tok of rest) {
      if (!tok || tok.startsWith('-')) continue;                        // flags
      if (/[\/\\]/.test(tok) || tok === '.' || tok.startsWith('.')) continue;  // local paths
      if (/^(?:https?|git\+|file|ssh):/i.test(tok)) continue;           // URLs / VCS installs
      if (/[<>=!~@]/.test(reg === 'pypi' ? tok : tok.replace(/^@[^/]+\/[^@]+/, ''))) {
        // has a version/extra specifier — strip it to the bare name
      }
      const name = bareName(tok, reg);
      if (name) out.push({ name, registry: reg });
    }
  }
  return out;
}

// Strip version specifiers / extras to the installable name. Skip -r requirements files.
function bareName(tok, reg) {
  if (/^-?r$/i.test(tok)) return null;
  if (reg === 'pypi') {
    // e.g. "requests==2.0", "fastapi[all]", "ruff>=0.1" -> requests / fastapi / ruff
    const n = tok.split(/[<>=!~;\[]/)[0].trim();
    return /^[A-Za-z0-9._-]+$/.test(n) ? n : null;
  }
  // npm: keep scope, strip trailing @version. "@scope/pkg@1.2" -> "@scope/pkg", "left-pad@1" -> "left-pad"
  let n = tok;
  if (n.startsWith('@')) { const parts = n.split('/'); if (parts.length >= 2) n = parts[0] + '/' + parts[1].split('@')[0]; }
  else n = n.split('@')[0];
  return /^@?[A-Za-z0-9._/-]+$/.test(n) ? n : null;
}

// Resolve true/false (exists / 404) or null (unknown -> treated as fail-open). 2.5s timeout each.
function existsOnRegistry(pkg) {
  return new Promise(resolve => {
    const host = pkg.registry === 'npm' ? 'registry.npmjs.org' : 'pypi.org';
    const p = pkg.registry === 'npm'
      ? '/' + encodeURIComponent(pkg.name).replace('%40', '@')      // npm keeps @ and / literal
      : '/pypi/' + encodeURIComponent(pkg.name) + '/json';
    const req = https.request({ host, path: p, method: 'HEAD', timeout: 2500 }, res => {
      res.resume();
      if (res.statusCode === 404) resolve(false);
      else if (res.statusCode >= 200 && res.statusCode < 400) resolve(true);
      else resolve(null);                                            // 5xx/429 etc -> unknown, fail open
    });
    req.on('timeout', () => { req.destroy(); resolve(null); });
    req.on('error', () => resolve(null));
    req.end();
  });
}
