#!/usr/bin/env node
/**
 * Notification + PermissionRequest hook: toast when Claude Code needs Douglas's input.
 *
 * Fires on permission_prompt (needs a tool approval) and idle_prompt (waiting
 * 60s+ for a reply) per the Notification hook payload's notification_type.
 * Notification hooks can't block or modify anything (Claude Code's own
 * contract) -- this is a pure side-effect, so it always exits 0.
 *
 * Added 2026-07-08 (Douglas: "add windows toast notifications when the cli asks questions as well"):
 * confirmed via the live debug log that AskUserQuestion does NOT go through the Notification event at
 * all -- it fires a SEPARATE "PermissionRequest" event ("executePermissionRequestHooks called for tool:
 * AskUserQuestion"), which had ZERO hooks wired to it. A real 208-second wait for a human answer produced
 * no toast the entire time. Also confirmed PermissionRequest did NOT fire for any other tool call this
 * session (only AskUserQuestion) -- so wiring this same script to BOTH events is safe, no double-toast
 * risk for ordinary Bash/Write/etc. approvals (those stay on the Notification event's permission_prompt
 * path, unchanged). This hook writes NO stdout JSON either way (side-effect only), so it can never
 * influence the actual permission decision on either event -- matching its own pre-existing contract.
 *
 * Popup mechanics copied from stop-toast-gate.js's proven pattern (hidden
 * PowerShell window via WScript.Shell, per the no-visible-PowerShell-windows
 * rule) rather than reinventing it.
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const STATE_FILE = path.join(os.tmpdir(), "claude-notification-toast-state.json");
const DEBOUNCE_MS = 5 * 1000; // 5 seconds -- just enough to absorb a double-fire

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

function escapeForPopup(s) {
  // Popup() takes a single-quoted PowerShell string; escape embedded quotes only.
  return String(s || "").replace(/'/g, "''").slice(0, 200);
}

function showToast(msg) {
  try {
    const cmd = `powershell.exe -NoProfile -WindowStyle Hidden -Command "(New-Object -ComObject Wscript.Shell).Popup('${escapeForPopup(msg)}',8,'Claude Code',64) | Out-Null"`;
    execSync(cmd, { timeout: 5000, stdio: "ignore" });
  } catch {}
}

// Pure logic, no side effects -- independently testable without triggering a real popup.
function buildMessage(payload) {
  let label, detail;
  if (payload.tool_name === "AskUserQuestion") {
    // PermissionRequest event, specifically AskUserQuestion -- surface the real question text when
    // available instead of a generic label (tool_input.questions[0].question, per the AskUserQuestion
    // tool's own schema).
    const questions = payload.tool_input && payload.tool_input.questions;
    const firstQuestion = Array.isArray(questions) && questions[0] && questions[0].question;
    label = "Claude has a question";
    detail = firstQuestion ? ` -- ${firstQuestion}` : (payload.message ? ` -- ${payload.message}` : "");
  } else {
    const type = payload.notification_type || "";
    label =
      type === "permission_prompt" ? "Claude needs permission"
      : type === "idle_prompt" ? "Claude is waiting on you"
      : type === "elicitation_dialog" ? "Claude has a question"
      : payload.tool_name ? `Claude needs permission for ${payload.tool_name}` // other PermissionRequest tools
      : "Claude needs your input";
    detail = payload.message ? ` -- ${payload.message}` : "";
  }
  return `${label}${detail}`;
}

function main() {
  const raw = readStdin();
  let payload = {};
  try {
    payload = JSON.parse(raw || "{}");
  } catch {}

  const state = loadState();
  const now = Date.now();

  if (now - state.lastToastAt < DEBOUNCE_MS) {
    process.exit(0);
  }

  showToast(buildMessage(payload));

  state.lastToastAt = now;
  saveState(state);
  process.exit(0);
}

if (require.main === module) main();

module.exports = { buildMessage, escapeForPopup };
