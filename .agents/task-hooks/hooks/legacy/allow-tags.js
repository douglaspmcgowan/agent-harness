#!/usr/bin/env node
'use strict';
// allow-tags.js — shared escape-hatch for the secret-scanning hooks.
//
// WHY: Douglas's secret hooks have repeatedly blocked his own harmless read-only / grep commands
// (documented recurring pain). Before this, the ONLY remedy for a specific false positive was to
// disable the whole hook — an all-or-nothing switch that leaves every other command unguarded.
// This adds a per-instance opt-in modeled on coo-quack/sensitive-canary's allow-tag design:
// the user puts a tag in their CURRENT prompt and only THAT one flagged case is let through.
//
// Tags (case-insensitive):
//   [allow-secret]  — allow this call past the secret/env-dump checks
//   [allow-all]     — allow this call past all sensitive-canary-style checks (superset)
//
// Safety properties (kept deliberately conservative — a bypass must be a conscious act):
//   1. Tags are read ONLY from the most recent USER text message in the session transcript.
//      A tag Claude writes in its own output does NOT count (only role === 'user' text blocks).
//   2. If any tool_result was recorded AFTER that last user text message, the tags are treated as
//      already consumed and are IGNORED. This means one tag authorizes essentially the first guarded
//      tool call after the user typed it — it does not silently persist across an entire turn or into
//      later turns. (Same "consumed by the first tool call" rule sensitive-canary uses.)
//   3. Tags in older messages are never honored — no accidental persistent bypass.
//   4. Fail CLOSED: any error reading/parsing the transcript returns "no tags" (i.e. the block stands).
//
// Usage in a blocking hook:
//   const { allowsSecret } = require(path.join(__dirname, 'allow-tags'));
//   if (allowsSecret(input)) process.exit(0);   // honor the escape hatch, then fall through to block

const fs = require('fs');

const MAX_TAIL_BYTES = 65536; // only ever look at the last 64 KB of a transcript

// Read the tail of the transcript file (JSONL). Returns '' on any error (fail closed).
function readTail(transcriptPath) {
  try {
    const stat = fs.statSync(transcriptPath);
    if (stat.size <= MAX_TAIL_BYTES) return fs.readFileSync(transcriptPath, 'utf8');
    const buf = Buffer.alloc(MAX_TAIL_BYTES);
    const fd = fs.openSync(transcriptPath, 'r');
    try {
      const n = fs.readSync(fd, buf, 0, MAX_TAIL_BYTES, stat.size - MAX_TAIL_BYTES);
      return buf.subarray(0, n).toString('utf8');
    } finally {
      fs.closeSync(fd);
    }
  } catch (_) {
    return '';
  }
}

// Pull the text out of a message.content that is either a plain string or an array of blocks.
function messageText(content) {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .filter((b) => b && b.type === 'text' && typeof b.text === 'string')
      .map((b) => b.text)
      .join('\n');
  }
  return '';
}

// Returns the Set of allow tags ('secret','pii','all',...) from the most recent user text message,
// but ONLY if no tool_result was recorded after it (else the tag is considered already consumed).
function activeAllowTags(input) {
  const transcriptPath = input && input.transcript_path;
  if (!transcriptPath) return new Set();
  const raw = readTail(transcriptPath);
  if (!raw) return new Set();

  let lastUserText = null;
  let toolResultAfterLastText = false;

  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let parsed;
    try { parsed = JSON.parse(trimmed); } catch (_) { continue; }
    const msg = parsed && parsed.message;
    if (!msg || msg.role !== 'user' || msg.content === undefined) continue;
    const text = messageText(msg.content);
    // A user turn with real text is a candidate tag source; a user turn that is ONLY a
    // tool_result (no text) marks that the previous tag has now been consumed by a tool call.
    const hasText =
      typeof msg.content === 'string'
        ? true
        : Array.isArray(msg.content) && msg.content.some((b) => b && b.type === 'text');
    if (hasText) {
      lastUserText = text;
      toolResultAfterLastText = false;
    } else {
      toolResultAfterLastText = true;
    }
  }

  if (lastUserText == null || toolResultAfterLastText) return new Set();

  const tags = new Set();
  const re = /\[allow-([a-z]+)\]/gi;
  let m;
  while ((m = re.exec(lastUserText)) !== null) tags.add(m[1].toLowerCase());
  return tags;
}

// Convenience: does the current prompt authorize bypassing a SECRET-category block?
function allowsSecret(input) {
  const tags = activeAllowTags(input);
  return tags.has('secret') || tags.has('all');
}

module.exports = { activeAllowTags, allowsSecret };
