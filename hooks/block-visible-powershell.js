#!/usr/bin/env node
'use strict';
// PreToolUse on Bash -- BLOCKS a command that invokes powershell/pwsh in a way that will flash a
// visible console window on Douglas's screen. Exit 2 = block (stderr reason relayed to Claude);
// exit 0 = allow.
//
// History: a warn-only predecessor (warn-visible-powershell.js, built 2026-07-04 after this first
// happened) fired non-blocking advice on every bad call but never stopped the command from running
// -- a warning can't un-flash a window that already appeared, and it demonstrably did not prevent
// recurrence within the same session (dozens of later calls in that same session still lacked the
// fix). Upgraded to a hard block same day.
//
// Root cause this catches, precisely: the -WindowStyle Hidden flag only hides the window of the
// process it's an argument TO. `powershell.exe -Command "Start-Process ... -WindowStyle Hidden"`
// puts the flag on the Start-Process TARGET, not on the outer `powershell.exe` process Bash itself
// spawns directly -- that outer process still gets a console window the instant it's created, before
// it ever parses its own arguments. This was the exact mistake made testing the dashboard watchdog:
// the flag was present in the command string, so a naive "does -WindowStyle Hidden appear anywhere"
// check would have missed it. Fix: call the target directly with -WindowStyle Hidden as THIS
// invocation's own top-level argument (no Start-Process needed) whenever possible.
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

// Segment boundary = start of command, or after ; & | (incl. && / ||), backtick, or $(.
const SEGMENT_SPLIT = /(?:^|[;&|`]|\$\()\s*/;
const INVOKES_POWERSHELL_AT_START = /^(powershell(\.exe)?|pwsh(\.exe)?)\b/i;
const HIDDEN_FLAG = /-w(indow)?s(tyle)?\s+hidden\b/i;
const START_PROCESS = /start-process/i;

function invokesPowershell(cmd) {
  // Only counts as an invocation if powershell/pwsh is the FIRST word of a command
  // segment -- e.g. `grep -i powershell` or `echo "not powershell"` must NOT match;
  // those are ordinary arguments/strings, not a process being launched.
  return cmd.split(SEGMENT_SPLIT).some((segment) => INVOKES_POWERSHELL_AT_START.test(segment.trimStart()));
}

function main() {
  const input = S.readStdin();
  if (input.tool_name !== 'Bash') return;
  const cmd = (input.tool_input && input.tool_input.command) || '';
  if (!invokesPowershell(cmd)) return;

  const hiddenMatch = HIDDEN_FLAG.exec(cmd);
  const startProcMatch = START_PROCESS.exec(cmd);

  if (!hiddenMatch) {
    block(
      cmd,
      'no -WindowStyle Hidden anywhere in the command -- this will flash a visible console window. ' +
      'Add -WindowStyle Hidden as a top-level argument to the powershell/pwsh invocation. Prefer a ' +
      'native tool (curl/netstat/tasklist/findstr) instead of PowerShell when one of those can do the job.',
    );
    return;
  }

  if (startProcMatch && hiddenMatch.index > startProcMatch.index) {
    block(
      cmd,
      '-WindowStyle Hidden is applied to the Start-Process TARGET, not to this outer powershell.exe ' +
      'process -- Bash still spawns THAT process directly and it will flash its own console window ' +
      'before it ever reaches your Start-Process line. Either (a) call the target directly with ' +
      '-WindowStyle Hidden as this invocation\'s own argument (Start-Process is usually unnecessary), ' +
      'or (b) if you genuinely need Start-Process semantics, add -WindowStyle Hidden to the OUTER call too.',
    );
    return;
  }
}

function block(cmd, reason) {
  process.stderr.write(`block-visible-powershell: ${reason}\nCommand: ${cmd.slice(0, 200)}\n`);
  process.exit(2);
}

try { main(); } catch (_) { /* fail open -- never block a normal Bash call on an unexpected error */ }
