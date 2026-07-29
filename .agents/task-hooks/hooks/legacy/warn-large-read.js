#!/usr/bin/env node
'use strict';
// PreToolUse — warns (never blocks) when a Read call pulls a large file in FULL (no offset/limit)
// into the main session's context instead of grepping or bounding it. Direct answer to Douglas's
// 2026-07-03 question "how do I keep bulk content out of the main thread" -- a chat-promised habit
// isn't a fix; this is the durable nudge. Detection-only, same philosophy as concurrent-edit-lock.js:
// never blocks a normal Read (hook_guarantee.js Invariant 3's spirit extended to this hook).
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

const LINE_THRESHOLD = 500; // above this, an unbounded Read is worth a nudge

function main() {
  const input = S.readStdin();
  const ti = input.tool_input || {};
  const filePath = ti.file_path;
  if (!filePath || ti.offset != null || ti.limit != null) return; // already bounded -- nothing to say

  let stat;
  try { stat = fs.statSync(filePath); } catch (_) { return; }
  if (!stat.isFile()) return;

  // Cheap line-count estimate without reading the whole file into memory: count newlines via a
  // bounded read of the first ~2MB, extrapolate if the file is bigger than that sample.
  const SAMPLE = 2 * 1024 * 1024;
  let sampleBuf;
  try {
    const fd = fs.openSync(filePath, 'r');
    const len = Math.min(stat.size, SAMPLE);
    sampleBuf = Buffer.alloc(len);
    fs.readSync(fd, sampleBuf, 0, len, 0);
    fs.closeSync(fd);
  } catch (_) { return; }
  let newlines = 0;
  for (let i = 0; i < sampleBuf.length; i++) if (sampleBuf[i] === 10) newlines++;
  const estimatedLines = stat.size <= SAMPLE ? newlines : Math.round(newlines * (stat.size / SAMPLE));

  if (estimatedLines > LINE_THRESHOLD) {
    process.stderr.write(
      `warn-large-read: ${path.basename(filePath)} is ~${estimatedLines.toLocaleString()} lines and is about to be ` +
      `read in FULL with no offset/limit -- it will sit in context for the rest of this session. If you only need ` +
      `part of it, Grep for the specific content instead, or Read with offset/limit. If you genuinely need the ` +
      `whole thing, this is just a heads-up, not a block.\n`);
  }
}

try { main(); } catch (_) { /* fail open -- never block or throw on a Read */ }
