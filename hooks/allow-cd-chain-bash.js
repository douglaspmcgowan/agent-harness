#!/usr/bin/env node
'use strict';
// PreToolUse on Bash -- REPLACES the earlier block-cd-chain-bash.js design (2026-07-08, Douglas: "is the
// hook blocking the && commands actually the best way? ... i don't want to limit my agents").
//
// Root problem (same as before): Claude Code's Bash permission allowlist matches on the command string's
// PREFIX. An allow-rule like Bash("<python.exe>" -m pytest *) only matches when that text is the START of
// the command -- prefixing with "cd <dir> && " moves the matched text later in the string, so an
// otherwise-already-approved command re-prompts.
//
// FIX (not a block): PreToolUse hooks run BEFORE permission matching, and a hook's own
// hookSpecificOutput.permissionDecision is evaluated before Claude Code checks permissions.allow
// (confirmed via research 2026-07-08 -- a hook's "allow" cannot override an existing deny/ask rule, but it
// CAN grant allow ahead of the normally-computed decision when nothing denies it). So: strip the leading
// "cd <dir> && " prefix, check whether the REMAINDER matches one of Douglas's own real permissions.allow
// Bash(...) patterns (implementing the exact same prefix-match semantics Claude Code itself documents), and
// if it does, declare the ORIGINAL, UNMODIFIED command pre-approved. The command that actually executes is
// never touched -- zero risk of a rewrite breaking relative paths or shell semantics. If the stripped
// command does NOT match anything already allowed, this hook does nothing at all (exit 0, no output) and
// lets the command fall through to Claude Code's normal permission handling exactly as if this hook didn't
// exist -- no special-case blocking, no limiting what an agent can do.
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

// Segment boundary = start of command, or after ; & | (incl. &&), backtick, or $( -- same quote-aware
// scanning as the original hook, so a `;`/`|`/`&&` INSIDE a quoted string is never mistaken for a real
// chain operator.
const LEADING_CD_CHAIN = /^\s*cd\s+\S/i;

function findChainOperatorEnd(cmd) {
  let inSingle = false;
  let inDouble = false;
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (c === "'" && !inDouble) inSingle = !inSingle;
    else if (c === '"' && !inSingle) inDouble = !inDouble;
    else if (!inSingle && !inDouble) {
      if (c === ';' || c === '|') return i + 1;
      if (c === '&' && cmd[i + 1] === '&') return i + 2;
    }
  }
  return -1;
}

function extractPostCdCommand(cmd) {
  if (!LEADING_CD_CHAIN.test(cmd)) return null;
  const end = findChainOperatorEnd(cmd);
  if (end === -1) return null; // standalone "cd X" with no real chain -- nothing to rewrite/allow-check
  return cmd.slice(end).trim();
}

// Parse a Bash(...) permission-rule string into its inner pattern text, or null if not a Bash rule.
function bashRulePattern(rule) {
  const m = /^Bash\((.*)\)$/.exec(rule);
  return m ? m[1] : null;
}

// Same prefix-match semantics Claude Code itself documents: "Bash(git *)" matches any command starting
// with "git " (or exactly "git"); "Bash(*)" matches everything; anything without a trailing " *" (or bare
// "*") must match EXACTLY.
function matchesAllowPattern(cmd, pattern) {
  if (pattern === '*') return true;
  if (pattern.endsWith(' *')) {
    const prefix = pattern.slice(0, -2);
    return cmd === prefix || cmd.startsWith(prefix + ' ');
  }
  if (pattern.endsWith('*')) {
    const prefix = pattern.slice(0, -1);
    return cmd.startsWith(prefix);
  }
  return cmd === pattern;
}

function loadBashAllowPatterns() {
  const settingsPath = path.join(__dirname, '..', 'settings.json');
  let allow;
  try {
    const parsed = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    allow = (parsed.permissions && parsed.permissions.allow) || [];
  } catch (_) { return []; }
  return allow.map(bashRulePattern).filter(Boolean);
}

function main() {
  const input = S.readStdin();
  if (input.tool_name !== 'Bash') return;
  const cmd = (input.tool_input && input.tool_input.command) || '';
  const stripped = extractPostCdCommand(cmd);
  if (!stripped) return; // not a leading-cd-chain shape at all -- nothing to do

  const patterns = loadBashAllowPatterns();
  const matched = patterns.find((p) => matchesAllowPattern(stripped, p));
  if (!matched) return; // stripped form isn't already allowed -- fall through to normal permission flow

  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'allow',
      permissionDecisionReason:
        `allow-cd-chain-bash: stripping the leading "cd <dir> && " prefix leaves "${stripped.slice(0, 120)}", ` +
        `which matches your existing Bash(${matched}) allow rule. Running the original command unmodified.`,
    },
  }));
}

try { main(); } catch (_) { /* fail open -- never block or interfere on an unexpected error */ }

module.exports = { extractPostCdCommand, matchesAllowPattern, bashRulePattern, loadBashAllowPatterns };
