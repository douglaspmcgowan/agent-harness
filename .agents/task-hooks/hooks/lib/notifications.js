'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const delay = Number(process.env.HARNESS_INPUT_TOAST_DELAY_MS || 10000);

function productFromArgs() {
  const value = process.argv.find(argument => argument.startsWith('--product='));
  return value ? value.slice('--product='.length).toLowerCase() : '';
}

function stateFile() {
  const root = process.env.HARNESS_STATE_DIR || path.join(os.homedir(), '.agents', 'state');
  return path.join(root, 'pending-input-toast.json');
}

function escapePowerShell(value) {
  return String(value || '').replace(/'/g, "''").slice(0, 240);
}

function showPopup(title, message) {
  if (process.env.HARNESS_NOTIFICATION_DRY_RUN === '1') return;
  const command =
    `(New-Object -ComObject Wscript.Shell).Popup('${escapePowerShell(message)}',8,` +
    `'${escapePowerShell(title)}',64) | Out-Null`;
  const child = spawn('powershell.exe', ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', command], {
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
  });
  child.unref();
}

function buildImmediateMessage(input) {
  const questions = input.tool_input && input.tool_input.questions;
  const question = Array.isArray(questions) && questions[0] && questions[0].question;
  if (input.tool_name === 'AskUserQuestion') return question ? `Agent question: ${question}` : 'Agent has a question.';
  const type = String(input.notification_type || '');
  if (type === 'permission_prompt') return input.message ? `Permission needed: ${input.message}` : 'Agent needs permission.';
  if (type === 'agent_complete') return input.message || 'Background agent finished.';
  if (type === 'idle_prompt') return input.message || 'Agent is waiting for input.';
  return input.message || 'Agent needs input.';
}

function cancelPending() {
  const file = stateFile();
  if (!fs.existsSync(file)) return;
  try {
    const state = JSON.parse(fs.readFileSync(file, 'utf8'));
    state.cancelled = true;
    state.cancelledAt = Date.now();
    fs.writeFileSync(file, JSON.stringify(state), 'utf8');
  } catch (_) {
    try { fs.unlinkSync(file); } catch (_) {}
  }
}

function schedulePending(input, reason, title, message) {
  const file = stateFile();
  fs.mkdirSync(path.dirname(file), { recursive: true });
  cancelPending();
  const token = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  fs.writeFileSync(file, JSON.stringify({
    token,
    title,
    message,
    reason,
    conversationId: input.conversation_id || input.session_id || '',
    firesAt: Date.now() + delay,
    cancelled: false,
    shown: false,
  }), 'utf8');
  if (process.env.HARNESS_NOTIFICATION_DRY_RUN === '1') return;
  const worker = path.join(__dirname, 'toast-worker.js');
  const child = spawn(process.execPath, [worker, token], {
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
    env: process.env,
  });
  child.unref();
}

function handleLifecycle(input, event) {
  const product = productFromArgs();
  const normalized = String(event || '').toLowerCase();
  if (product === 'claude' && (normalized === 'notification' || normalized === 'permissionrequest')) {
    const message = buildImmediateMessage(input);
    showPopup('Claude Code', message);
    return { action: 'shown', message };
  }
  if (product !== 'cursor') return null;

  if (['beforesubmitprompt', 'sessionstart', 'posttooluse'].includes(normalized)) {
    cancelPending();
    return { action: 'cancelled' };
  }
  if (normalized === 'beforeshellexecution') {
    const command = String(input.command || (input.tool_input && input.tool_input.command) || '').trim();
    schedulePending(input, 'shell-approval', 'Approve terminal command', command.slice(0, 120) || 'Shell command waiting.');
    return { action: 'scheduled', reason: 'shell-approval' };
  }
  if (normalized === 'beforemcpexecution') {
    schedulePending(input, 'mcp-approval', 'Approve MCP action', `${input.tool_name || 'MCP tool'} is waiting.`);
    return { action: 'scheduled', reason: 'mcp-approval' };
  }
  if (normalized === 'afteragentresponse') {
    schedulePending(input, 'after-agent-response', 'Cursor is waiting', 'Agent finished a turn.');
    return { action: 'scheduled', reason: 'after-agent-response' };
  }
  return null;
}

function handleAllowedStop(input) {
  if (productFromArgs() !== 'cursor') return null;
  schedulePending(input, 'stop', 'Cursor is waiting', 'Agent finished; reply in chat when ready.');
  return { action: 'scheduled', reason: 'stop' };
}

module.exports = {
  delay,
  productFromArgs,
  stateFile,
  escapePowerShell,
  buildImmediateMessage,
  showPopup,
  cancelPending,
  schedulePending,
  handleLifecycle,
  handleAllowedStop,
};
