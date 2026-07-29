#!/usr/bin/env node
'use strict';
// PostToolUse hook (TaskCreate|TaskUpdate|TaskStop): mirror THIS session's in-chat task board into a durable,
// project+session-scoped CURRENT-TASK.<sid>.md so the convenient in-chat board becomes a system of record that
// (a) survives a cold reopen (session-primer reloads it) and (b) ARMS keep-going via its "- [ ]"/"- [~]" lines —
// without relying on the model's discipline to hand-maintain the file.
//
// Source of truth = Claude Code's own board store at ~/.claude/tasks/<session_id>/N.json
//   { id, subject, description, activeForm, status, blocks, blockedBy }   status in {pending,in_progress,completed,...}
// Destination = <root>/taskstate/<project>/CURRENT-TASK.<sid>.md, routed via hook-state.js (same keying as
// keep-going / task-state-reminder). Only the marked AUTO block is rewritten; hand-written sections are preserved.
//
// FAIL OPEN: any error is swallowed; this hook never blocks a tool call and never emits blocking output.
const path = require('path');
const fs = require('fs');
const os = require('os');
const S = require(path.join(__dirname, 'hook-state.js'));

const START = '<!-- TASKS:AUTO START (mirrored from the in-chat board by mirror-tasks-to-current.js — do not edit between these markers) -->';
const END = '<!-- TASKS:AUTO END -->';

function checkbox(t) {
  const st = String((t && t.status) || '').toLowerCase();
  if (st === 'completed') return '[x]';
  if (st === 'in_progress') return '[~]';
  if (Array.isArray(t && t.blockedBy) && t.blockedBy.length) return '[!]'; // parked: keep-going treats [!] as non-actionable
  return '[ ]';
}

function renderBlock(tasks) {
  const lines = [START, '', '## Task board (auto — mirrored from the in-chat board)'];
  if (!tasks.length) {
    lines.push('', '_(no tasks on the board)_');
  } else {
    for (const t of tasks) {
      const subj = String((t && (t.subject || t.activeForm)) || '(untitled)').replace(/\s+/g, ' ').trim();
      lines.push('- ' + checkbox(t) + ' ' + subj);
    }
  }
  lines.push('', END);
  return lines.join('\n');
}

(function () {
  try {
    const input = S.readStdin();
    const s = S.sid(input);
    if (!s) return; // no session id -> nothing to scope to

    // Load the in-chat board for THIS session.
    const taskDir = path.join(os.homedir(), '.claude', 'tasks', s);
    let tasks = [];
    try {
      tasks = fs.readdirSync(taskDir)
        .filter(f => /\.json$/i.test(f))
        .map(f => { try { return JSON.parse(fs.readFileSync(path.join(taskDir, f), 'utf8')); } catch (_) { return null; } })
        .filter(Boolean)
        .sort((a, b) => (Number(a.id) || 0) - (Number(b.id) || 0));
    } catch (_) { tasks = []; } // no board yet -> empty (still writes an empty marked block, which is harmless)

    const block = renderBlock(tasks);

    const dest = S.sessionDocWrite(input, 'CURRENT-TASK'); // canonical state-dir path for this (project, sid)
    if (!S.ensureDir(path.dirname(dest))) return; // unwritable -> fail open, do nothing

    let prev = '';
    try { prev = fs.readFileSync(dest, 'utf8'); } catch (_) { prev = ''; }

    let next;
    const i0 = prev.indexOf(START);
    const i1 = prev.indexOf(END);
    if (i0 !== -1 && i1 !== -1 && i1 > i0) {
      // replace just the existing auto block; preserve everything around it
      next = prev.slice(0, i0) + block + prev.slice(i1 + END.length);
    } else if (prev.trim()) {
      next = prev.replace(/\s*$/, '') + '\n\n' + block + '\n'; // append after hand-written content
    } else {
      next = block + '\n';
    }

    if (next !== prev) fs.writeFileSync(dest, next);
  } catch (_) { /* fail open */ }
})();
