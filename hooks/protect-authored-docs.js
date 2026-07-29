#!/usr/bin/env node
// Protects Douglas-authored Office docs (.pptx/.docx/.xlsx) from destructive in-place overwrite.
// Enforces the rule: back up the original first, then write output to a NEW versioned file.
// - Write/Edit: blocks ONLY when the target already exists (creating a new versioned file is allowed).
// - Bash: blocks overwrite verbs (os.replace/os.rename/shutil.move/mv/Move-Item -Force) aimed at an Office file.
//   Plain `cp`/`Copy-Item` (the required backup step) is NOT blocked.
const fs = require('fs');
const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const tool = input.tool_name || '';
    const ti = input.tool_input || {};
    const OFFICE_PATH = /\.(pptx|docx|xlsx)$/i;   // for a real file path (end-anchored)
    const OFFICE_ANY = /\.(pptx|docx|xlsx)\b/i;    // for scanning inside a command string
    const block = (msg) =>
      process.stdout.write(JSON.stringify({ continue: false, stopReason: msg }));

    if (tool === 'Write' || tool === 'Edit') {
      const p = ti.file_path || '';
      if (OFFICE_PATH.test(p) && fs.existsSync(p)) {
        return block(
          `Blocked: "${p}" is an existing Douglas-authored Office file. Do NOT overwrite it in place. ` +
          `Back it up to <folder>/_backups/<name>.BACKUP_<yyyyMMdd_HHmmss>.<ext>, then write your output to a NEW versioned filename. ` +
          `Also confirm the app (PowerPoint/Word/Excel) is fully closed before you read it — a stale read drops unsaved edits.`
        );
      }
    }

    if (tool === 'Bash' || tool === 'PowerShell') {
      const cmd = ti.command || '';
      const overwriteVerb = /os\.replace|os\.rename|shutil\.move|\bmv\b|Move-Item\b[^|;\n]*-Force/i.test(cmd);
      if (OFFICE_ANY.test(cmd) && overwriteVerb) {
        return block(
          `Blocked: this command moves/overwrites an Office file (.pptx/.docx/.xlsx) in place ` +
          `(os.replace / os.rename / shutil.move / mv / Move-Item -Force). ` +
          `Never overwrite a Douglas-authored doc. Back up to _backups/ first (cp/Copy-Item is fine), then write a NEW versioned file.`
        );
      }
    }
  } catch (_) {}
});
