#!/usr/bin/env node
'use strict';
// PreToolUse on Bash -- BLOCKS a command that starts with "cd <path> && ..." (or ; / |-chained after a
// leading cd). Exit 2 = block (stderr reason relayed to Claude); exit 0 = allow.
//
// Root cause this catches (found 2026-07-07, ai-for-cad/cad-forge session): Claude Code's Bash permission
// allowlist matches on the COMMAND STRING'S PREFIX. An allow-rule written for "<python.exe> -m pytest *"
// matches only when that text is the START of the command -- prefixing it with "cd <dir> && " moves the
// matched text later in the string and the rule no longer matches, so an otherwise-already-approved command
// re-prompts for approval. This was confirmed directly: a subagent's `cd "..." && "...python.exe"
// test_fillet_extract.py 2>&1 | tail -30` was rejected mid-session even though the bare form
// `"...python.exe" test_fillet_extract.py` was already allow-listed. The Bash tool's own cwd does not
// usefully persist to the NEXT call either (confirmed empirically the same session), so there is no
// upside to `cd X && ...` -- the target path can always be passed directly as an argument to the command
// instead (relative to the fixed per-call root, or as an absolute path).
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

// A leading `cd <something>` followed by a real shell chain operator (&&, ;, or a pipe) outside of a
// quoted string. Anchored at the START of the command -- a bash call that merely CONTAINS "cd" later
// (e.g. as an argument, inside a string) must not match.
const LEADING_CD_CHAIN = /^\s*cd\s+\S/i;

function hasChainOperatorOutsideQuotes(cmd) {
  let inSingle = false;
  let inDouble = false;
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (c === "'" && !inDouble) inSingle = !inSingle;
    else if (c === '"' && !inSingle) inDouble = !inDouble;
    else if (!inSingle && !inDouble) {
      if (c === ';' || c === '|') return true;
      if (c === '&' && cmd[i + 1] === '&') return true;
    }
  }
  return false;
}

function main() {
  const input = S.readStdin();
  if (input.tool_name !== 'Bash') return;
  const cmd = (input.tool_input && input.tool_input.command) || '';
  if (!LEADING_CD_CHAIN.test(cmd)) return;
  if (!hasChainOperatorOutsideQuotes(cmd)) return;

  process.stderr.write(
    'block-cd-chain-bash: leading "cd <dir> && ..." breaks Bash permission-allowlist prefix matching -- ' +
    'an already-approved command re-prompts the user because the chained prefix moved the matched text. ' +
    'Drop the cd and pass the target path directly as an argument to the command (relative to the fixed ' +
    'per-call working directory, or an absolute path) instead. If you genuinely need a persistent cwd ' +
    'change across several separate calls, issue "cd <dir>" as its own standalone Bash call -- but note it ' +
    'does not reliably persist to the next call either, so a direct path argument is usually simpler.\n' +
    `Command: ${cmd.slice(0, 200)}\n`,
  );
  process.exit(2);
}

try { main(); } catch (_) { /* fail open -- never block a normal Bash call on an unexpected error */ }
