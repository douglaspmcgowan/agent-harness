#!/usr/bin/env node
/**
 * Stop hook: only show "Claude finished" toast for genuine user-facing stops.
 *
 * Suppresses the toast when:
 *  - Stop is happening because Claude is awaiting a tool result (intermediate)
 *  - There's an active CURRENT-TASK.md with unchecked items in the project root
 *  - The previous stop fired <30s ago (debounce — prevents toast spam during
 *    long agentic runs that hit Stop multiple times)
 *
 * Prior behavior: every Stop fired a popup, including intermediate stops mid-task,
 * which made the toast meaningless ("Claude finished... Claude finished... Claude finished...").
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const STATE_FILE = path.join(os.tmpdir(), "claude-stop-toast-state.json");
const DEBOUNCE_MS = 30 * 1000; // 30 seconds

function readStdin() {
  try {
    return fs.readFileSync(0, "utf8");
  } catch {
    return "";
  }
}

function loadState() {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
  } catch {
    return { lastToastAt: 0 };
  }
}

function saveState(state) {
  try {
    fs.writeFileSync(STATE_FILE, JSON.stringify(state));
  } catch {}
}

function projectHasOpenTaskFile(cwd) {
  const candidates = [
    path.join(cwd, "CURRENT-TASK.md"),
    path.join(cwd, "..", "CURRENT-TASK.md"),
  ];
  for (const p of candidates) {
    try {
      const content = fs.readFileSync(p, "utf8");
      // If the file has any unchecked checkboxes, the task isn't done
      if (/^\s*-\s*\[\s\]/m.test(content)) return true;
    } catch {}
  }
  return false;
}

function showToast(msg) {
  try {
    const cmd = `powershell.exe -NoProfile -WindowStyle Hidden -Command "(New-Object -ComObject Wscript.Shell).Popup('${msg}',3,'Claude Code',64) | Out-Null"`;
    execSync(cmd, { timeout: 5000, stdio: "ignore" });
  } catch {}
}

function main() {
  const raw = readStdin();
  let payload = {};
  try {
    payload = JSON.parse(raw || "{}");
  } catch {}

  const cwd = payload.cwd || process.cwd();
  const state = loadState();
  const now = Date.now();

  // 1. Debounce: skip if we toasted recently
  if (now - state.lastToastAt < DEBOUNCE_MS) {
    process.exit(0);
  }

  // 2. Skip if there's an active CURRENT-TASK.md with unchecked items
  //    (we're not actually finished, just paused)
  if (projectHasOpenTaskFile(cwd)) {
    process.exit(0);
  }

  // 3. Skip if Stop was triggered with `stop_hook_active` flag (re-entrant stop)
  if (payload.stop_hook_active) {
    process.exit(0);
  }

  // Otherwise: legitimate stop, show the toast.
  showToast("Claude finished");
  state.lastToastAt = now;
  saveState(state);
  process.exit(0);
}

main();
