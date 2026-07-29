/**
 * check-session-size.js
 * Stop hook — runs silently after each Claude turn.
 * Warns in-terminal when the current session JSONL is getting large.
 *
 * Thresholds:
 *   >= 8 MB  → yellow advisory (consider rolling over soon)
 *   >= 16 MB → red warning (roll over before next task)
 */

"use strict";

const fs = require("fs");
const path = require("path");

const WARN_MB = 8;
const URGENT_MB = 16;
const WARN_BYTES = WARN_MB * 1024 * 1024;
const URGENT_BYTES = URGENT_MB * 1024 * 1024;

const projectsDir = path.join(process.env.USERPROFILE, ".claude", "projects");

if (!fs.existsSync(projectsDir)) process.exit(0);

// Find the most recently modified .jsonl across all project subdirectories.
// The current session's file will always have the freshest mtime.
let latestFile = null;
let latestMtime = 0;

try {
  for (const entry of fs.readdirSync(projectsDir)) {
    const projPath = path.join(projectsDir, entry);
    if (!fs.statSync(projPath).isDirectory()) continue;

    for (const file of fs.readdirSync(projPath)) {
      if (!file.endsWith(".jsonl")) continue;
      const filePath = path.join(projPath, file);
      const stat = fs.statSync(filePath);
      if (stat.mtimeMs > latestMtime) {
        latestMtime = stat.mtimeMs;
        latestFile = { filePath, size: stat.size, name: file };
      }
    }
  }
} catch (_) {
  process.exit(0);
}

if (!latestFile) process.exit(0);

const { size, name } = latestFile;
const sizeMB = (size / (1024 * 1024)).toFixed(1);
const shortId = name.replace(".jsonl", "").slice(0, 8);

if (size >= URGENT_BYTES) {
  console.log(
    `\n[SESSION ${sizeMB} MB] Over ${URGENT_MB} MB — roll over before your next task.`,
  );
  console.log(
    `  Session: ${shortId}...  Run rollover-session.ps1 then start a fresh session.\n`,
  );
} else if (size >= WARN_BYTES) {
  console.log(
    `\n[Session ${sizeMB} MB] Getting large — consider rolling over after this task.\n`,
  );
}
// Below WARN_MB: silent.
