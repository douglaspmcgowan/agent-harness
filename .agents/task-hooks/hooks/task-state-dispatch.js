#!/usr/bin/env node
'use strict';

// One lifecycle dispatcher for TASK.md. It surfaces deterministic state and reminders.
// Prompt-to-obligation extraction remains agent judgment.

const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'lib', 'task-state.js'));
const D = require(path.join(__dirname, 'lib', 'lifecycle-diagnostics.js'));
const N = require(path.join(__dirname, 'lib', 'notifications.js'));

const DEFAULT_STARTUP_LIMIT = 24000;

function eventName(input) {
  return String(process.argv[2] || input.hook_event_name || input.hookEventName || '').toLowerCase();
}

function first(paths) {
  return Array.isArray(paths) && paths.length ? paths[0] : null;
}

function read(file) {
  try { return fs.readFileSync(file, 'utf8').trim(); } catch (_) { return ''; }
}

function startupLimit() {
  const requested = Number(process.env.HARNESS_STARTUP_MAX_CHARS || DEFAULT_STARTUP_LIMIT);
  return Number.isFinite(requested) && requested >= 512
    ? Math.min(Math.floor(requested), DEFAULT_STARTUP_LIMIT)
    : DEFAULT_STARTUP_LIMIT;
}

function excerpt(content, limit) {
  const value = String(content || '').trim();
  if (value.length <= limit) return value;
  const clipped = value.slice(0, Math.max(0, limit - 80)).replace(/\s+$/, '');
  return `${clipped}\n\n… startup excerpt clipped; open the source file for the rest.`;
}

function task(input) {
  const file = first(S.sessionDocCandidates(input, 'TASK'));
  if (!file) return { file: null, content: '', status: S.parseTaskDocument('') };
  const content = read(file);
  return { file, content, status: S.parseTaskDocument(content) };
}

function emit(event, parts) {
  if (!parts.length) return;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: event,
      additionalContext: parts.join('\n\n---\n\n'),
    },
  }));
}

function sessionStart(input) {
  const project = S.resolveProject(input);
  const parts = [];
  const current = task(input);
  const next = current.status.actionable.slice(0, 10);

  if (next.length) parts.push(`## Next TASK.md items\n- ${next.join('\n- ')}`);
  if (current.content) parts.push(`## TASK.md (${project.id})\n${excerpt(current.content, 12000)}`);

  const status = first(S.projectDocCandidates(input, 'STATUS.md'));
  if (status) parts.push(`## STATUS.md\n${excerpt(read(status), 5000)}`);

  const log = first(S.projectDocCandidates(input, 'LOG.md'));
  if (log) {
    const lines = read(log).split(/\r?\n/).filter(Boolean);
    if (lines.length) parts.push(`## LOG.md — recent\n${excerpt(lines.slice(-10).join('\n'), 3000)}`);
  }

  const warnings = D.sessionSelfChecks(input, S);
  if (warnings.length) parts.unshift(`## Harness self-check\n- ${warnings.join('\n- ')}`);

  const state = current.status.actionable.length
    ? `ARMED — ${current.status.actionable.length} actionable TASK.md item(s).`
    : 'INERT — no actionable TASK.md items.';
  parts.unshift(`## Continuation state\n${state}`);
  emit('SessionStart', [excerpt(parts.join('\n\n---\n\n'), startupLimit())]);
}

function promptSubmit(input) {
  const current = task(input);
  const parts = [];
  const prompt = String(input.prompt || input.user_prompt || '');
  D.appendPromptTelemetry(input, S);

  const listSignals = (prompt.match(/^\s*(?:[-*+]|\d+[.)])\s+/gm) || []).length;
  const sequenceSignals = (prompt.match(/\b(?:also|then|and then|after that|finally)\b/gi) || []).length;
  const multiStep = listSignals >= 2 || sequenceSignals >= 2;

  if (current.status.actionable.length) {
    parts.push(
      `TASK.md has ${current.status.actionable.length} actionable item(s). Reconcile this prompt into TASK.md before ` +
      `implementation: add every new required obligation as a checkbox, update corrections or cancellations, and ` +
      `record every direct and embedded question as a queue task with completion evidence. Do not create an Answers ` +
      `section. Keep the next verifier current. Required agent-created work may be a nested checkbox with an ` +
      `\`<!-- agent: product/session -->\` provenance comment. Put optional discoveries in BACKBURNER.md. ` +
      `Use parallel mode when three or more independent, file-disjoint items are eligible.`
    );
  } else if (multiStep || !current.file) {
    parts.push(
      `This prompt appears multi-step or TASK.md is missing. Create or reconcile TASK.md before implementation. ` +
      `Extract discrete required tasks and every direct or embedded question as queue checkboxes without inventing ` +
      `optional work. Do not create an Answers section.`
    );
  }

  for (const diagnostic of [
    D.surfaceNeedsApproval(input, S),
    D.recentHookTimeouts(input),
    D.recentStopFailures(input),
    D.skillNudge(input),
    D.pathwayNudge(input, S),
  ]) {
    if (diagnostic) parts.push(diagnostic);
  }
  emit('UserPromptSubmit', parts);
}

function preCompact(input) {
  const current = task(input);
  if (current.file || !S.sessionId(input)) return;
  const trigger = String(input.trigger || input.matcher || '').toLowerCase();
  if (trigger === 'auto') return;

  let turns = 0;
  try {
    const transcript = fs.readFileSync(S.norm(input.transcript_path || ''), 'utf8');
    for (const line of transcript.split(/\r?\n/)) {
      let record;
      try { record = JSON.parse(line); } catch (_) { continue; }
      if (record && record.type === 'user' && record.message && typeof record.message.content === 'string') {
        turns += 1;
      }
    }
  } catch (_) {}
  if (turns < 3) return;

  const marker = S.sessionFlagWrite(input, '.precompact-manual-block');
  try {
    const age = Date.now() - fs.statSync(marker).mtimeMs;
    if (age <= 15 * 60 * 1000) {
      fs.unlinkSync(marker);
      return;
    }
  } catch (_) {}
  try {
    S.ensureDir(path.dirname(marker));
    fs.writeFileSync(marker, new Date().toISOString(), 'utf8');
  } catch (_) {}
  process.stderr.write(
    `task-state-dispatch: TASK.md is missing after ${turns} human turns; capture active and remaining ` +
    `work before manual compaction. A second manual compact within 15 minutes overrides this guard.\n`
  );
  process.exit(2);
}

function postTaskTool(input) {
  const tool = String(input.tool_name || input.tool || '');
  if (!/^(TaskCreate|TaskUpdate|TaskStop)$/i.test(tool)) return;
  emit('PostToolUse', [
    'The product task board changed. Reconcile the durable TASK.md ledger now; the product board is volatile.',
  ]);
}

function main() {
  const input = S.readStdin();
  const event = eventName(input);
  N.handleLifecycle(input, event);
  if (event === 'sessionstart') sessionStart(input);
  else if (event === 'userpromptsubmit' || event === 'beforesubmitprompt') promptSubmit(input);
  else if (event === 'precompact') preCompact(input);
  else if (event === 'posttooluse') postTaskTool(input);
}

try { main(); } catch (_) { process.exit(0); }

module.exports = {
  eventName,
  startupLimit,
  excerpt,
  task,
  sessionStart,
  promptSubmit,
  preCompact,
  postTaskTool,
};
