'use strict';

// Extracted from the existing keep-going.js R14 implementation.

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

function readLoop(cwd) {
  const file = path.join(cwd, '.claude', 'ralph-loop.local.md');
  let raw;
  try { raw = fs.readFileSync(file, 'utf8'); } catch (_) { return null; }
  const match = /^---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n?([\s\S]*)$/.exec(raw);
  if (!match) return null;
  const frontmatter = {};
  for (const line of match[1].split(/\r?\n/)) {
    const field = /^([A-Za-z_]+):\s*(.*)$/.exec(line);
    if (field) frontmatter[field[1]] = field[2].trim();
  }
  return { file, raw, frontmatter, prompt: (match[2] || '').trim() };
}

function recentAssistantText(transcriptPath) {
  let data;
  try { data = fs.readFileSync(transcriptPath, 'utf8'); } catch (_) { return ''; }
  const blocks = [];
  for (const line of data.split(/\r?\n/).filter(Boolean).slice(-400)) {
    let record;
    try { record = JSON.parse(line); } catch (_) { continue; }
    const message = record && record.message;
    if (!message || message.role !== 'assistant') continue;
    const content = message.content;
    if (Array.isArray(content)) {
      for (const block of content) {
        if (block && block.type === 'text' && typeof block.text === 'string') blocks.push(block.text);
      }
    } else if (typeof content === 'string') {
      blocks.push(content);
    }
  }
  return blocks.join('\n');
}

function promiseFound(text, token) {
  if (!token) return false;
  const normalize = value => String(value).replace(/\s+/g, ' ').trim();
  const expected = normalize(token);
  const pattern = /<promise>([\s\S]*?)<\/promise>/gi;
  let match;
  while ((match = pattern.exec(text || '')) !== null) {
    if (normalize(match[1]) === expected) return true;
  }
  return false;
}

function remove(file) {
  try { fs.unlinkSync(file); } catch (_) {}
}

function evaluateCompletionLoop(input, taskStatus) {
  const cwd = String(input.cwd || process.cwd());
  const loop = readLoop(cwd);
  if (!loop) return null;

  const sid = String(input.session_id || '');
  const owner = String(loop.frontmatter.session_id || '').trim();
  if (owner && owner !== sid) return { code: 0, message: 'completion loop belongs to another session' };

  const iteration = Number.parseInt(loop.frontmatter.iteration, 10);
  const maximum = Number.parseInt(loop.frontmatter.max_iterations, 10);
  if (!Number.isFinite(iteration) || !Number.isFinite(maximum)) {
    remove(loop.file);
    return { code: 0, message: 'corrupt completion loop cleared' };
  }
  if (maximum > 0 && iteration >= maximum) {
    remove(loop.file);
    return { code: 0, message: `completion loop reached ${maximum} iterations` };
  }
  if (taskStatus && !taskStatus.actionable.length && !taskStatus.malformed.length && taskStatus.parked.length) {
    return { code: 0, message: 'completion loop paused because TASK.md contains only parked items' };
  }

  let nonce = String(loop.frontmatter.nonce || '').trim();
  if (nonce && promiseFound(recentAssistantText(String(input.transcript_path || '')), nonce)) {
    remove(loop.file);
    return { code: 0, message: 'completion token detected' };
  }

  if (!nonce) nonce = crypto.randomBytes(6).toString('hex');
  let updated = loop.raw.replace(/^iteration:.*$/m, `iteration: ${iteration + 1}`);
  if (!/^nonce:/m.test(updated)) updated = updated.replace(/^(iteration:.*)$/m, `$1\nnonce: ${nonce}`);
  try { fs.writeFileSync(loop.file, updated, 'utf8'); } catch (_) {
    return { code: 0, message: 'completion loop state could not be persisted; failing open' };
  }

  const label = String(loop.frontmatter.completion_promise || '').replace(/^"(.*)"$/, '$1').trim();
  const message =
    `KEEP GOING — completion loop iteration ${iteration + 1}${maximum > 0 ? `/${maximum}` : ''}. ` +
    `${label ? `Goal: ${label}. ` : ''}Continue the task. Finish only when the goal is verified. ` +
    `Completion token: ${nonce}. Emit <promise>${nonce}</promise> only as the final verified completion signal.` +
    `${loop.prompt ? `\n\n${loop.prompt}` : ''}`;
  return { code: 2, message };
}

module.exports = { readLoop, recentAssistantText, promiseFound, evaluateCompletionLoop };
