#!/usr/bin/env node
// Block dangerous bash commands before they execute.
// Exit 2 = block the action and tell Claude why (Claude relays to the user).
// Covers OS/filesystem catastrophes AND destructive git/SQL ops — keep ALL (user, 2026-05-23).
//
// 2026-07-06 hardening (additive only): (1) folded in the refinements that had lived in the
// unused block-dangerous-bash.proposed.js draft — --force-with-lease is now allowed (it fails
// safely on remote divergence), the bare `git push -f` short flag is now blocked (was a false
// NEGATIVE), a single-file `git checkout -- src/x` is allowed while the bulk `git checkout -- .`/`*`
// stays blocked, and DROP/TRUNCATE TABLE only trip when actually piped through a real DB client
// (so `echo "DROP TABLE"` / `grep "DROP TABLE"` no longer false-positive). (2) Added detection of
// a destructive command DISGUISED inside a `python -c` / `node -e` / `ruby -e` / `perl -e`
// one-liner — a distinct evasion class (mechanism mined from kenryu42/cc-safety-net's
// interpreters.ts + DANGEROUS_PATTERNS). The draft file is now superseded and can be deleted.
const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
const cmd = (data.tool_input && data.tool_input.command) || "";

const dangerous = [
  // ── OS / filesystem catastrophes ──
  { pattern: /\brm\s+-rf\s+\/(\s|$)/, label: "rm -rf /" },
  { pattern: /\brm\s+-rf\s+~(\s|$|\/)/, label: "rm -rf ~" },
  { pattern: /\brm\s+-rf\s+\*(\s|$)/, label: "rm -rf *" },
  { pattern: /\brm\s+-[a-z]*r[a-z]*f\s+[\/~]/, label: "rm -rf on root/home" },
  { pattern: /\brm\s+-[a-z]*f[a-z]*r\s+[\/~]/, label: "rm -rf on root/home" },
  { pattern: /:\(\)\s*\{.*\}.*:&/, label: "fork bomb" },
  { pattern: /\bmkfs\./, label: "filesystem format (mkfs)" },
  {
    pattern: /\bdd\s+[^|]*\bof=\/dev\/(sd|hd|nvme)/,
    label: "raw disk overwrite (dd)",
  },
  {
    pattern: />\s*\/dev\/(sd|hd|nvme)[a-z0-9]*\s*$/,
    label: "raw disk overwrite",
  },
  { pattern: /\bshutdown\s+(-[hr]|\/[hrs])/i, label: "system shutdown" },
  // ── destructive git ──
  {
    // --force blocks; --force-with-lease (safe: fails on remote divergence) does not.
    pattern: /\bgit\s+push\b[^\n]*(?:--force\b(?!-with-lease)|\s-f(?:\s|$))/,
    label: "git push --force",
  },
  { pattern: /git\s+reset\s+--hard/, label: "git reset --hard" },
  { pattern: /git\s+clean\s+-[a-z]*f/, label: "git clean -f" },
  {
    // Only the bulk/wildcard form is catastrophic; discarding one named file is routine.
    pattern: /git\s+checkout\s+--\s+(?:\.|\*)(?:\s|$)/,
    label: "git checkout -- (discard changes)",
  },
  { pattern: /git\s+branch\s+-D\s/, label: "git branch -D (force delete)" },
  { pattern: /git\s+rebase\s+-i/, label: "git rebase -i (interactive)" },
  // ── destructive SQL (only when actually run through a DB client, not echoed/grepped text) ──
  {
    // (?<!["']) keeps a quoted mention of the client name (e.g. inside an echo string) from counting.
    pattern: /(?<!["'])\b(?:psql|mysql|mysqladmin|sqlite3|mongosh|mongo|sqlcmd|osql|sqlplus)\b[\s\S]*?\bDROP\s+TABLE\b/i,
    label: "DROP TABLE via DB client",
  },
  {
    pattern: /(?<!["'])\b(?:psql|mysql|mysqladmin|sqlite3|mongosh|mongo|sqlcmd|osql|sqlplus)\b[\s\S]*?\bTRUNCATE\s+TABLE\b/i,
    label: "TRUNCATE TABLE via DB client",
  },
];

// ── Destructive ops disguised inside an interpreter one-liner ──────────────────
// e.g.  python -c "import os; os.system('rm -rf /tmp/x')"   or   node -e "require('fs').rmSync(...)"
// A bare `rm -rf /` is already caught above, but wrapping it in `python -c '...'` slips past every
// pattern that anchors on the command being the literal first token. Mechanism ported from
// cc-safety-net (src/core/analyze/interpreters.ts + DANGEROUS_PATTERNS in src/types.ts): pull the
// string argument that follows -c / -e for a known interpreter, then re-scan THAT string for the
// same destructive shapes. Additive: this only ever ADDS a block; it can never un-block anything.
const INTERP = /\b(?:python[0-9.]*|python3?|node|nodejs|ruby|perl|deno|bun)\b/i;

// Destructive shapes to look for INSIDE the extracted interpreter payload. Kept deliberately
// focused on irrecoverable actions (matches cc-safety-net's DANGEROUS_PATTERNS set) plus the
// language-native destructive calls (os.system/subprocess, fs.rmSync/unlinkSync, shutil.rmtree).
const DANGEROUS_IN_CODE = [
  { pattern: /\brm\s+-[a-z]*r[a-z]*f|\brm\s+-[a-z]*f[a-z]*r/i, label: "rm -rf (in interpreter one-liner)" },
  { pattern: /\bgit\s+reset\s+--hard/i, label: "git reset --hard (in interpreter one-liner)" },
  { pattern: /\bgit\s+checkout\s+--\s+(?:\.|\*)/i, label: "git checkout -- . (in interpreter one-liner)" },
  { pattern: /\bgit\s+clean\s+-[a-z]*f/i, label: "git clean -f (in interpreter one-liner)" },
  { pattern: /\bgit\s+push\b[^\n]*(?:--force\b(?!-with-lease)|\s-f(?:\s|$))/i, label: "git push --force (in interpreter one-liner)" },
  { pattern: /\bmkfs(?:\.[A-Za-z0-9_-]+)?\s+\/dev\//i, label: "mkfs (in interpreter one-liner)" },
  { pattern: /\bdd\b[^\n;&|]*\bof=\/dev\//i, label: "dd of=/dev/ (in interpreter one-liner)" },
  { pattern: /\bshred\b\s+/i, label: "shred (in interpreter one-liner)" },
  { pattern: /\bfind\b[^\n]*\s-delete\b/i, label: "find -delete (in interpreter one-liner)" },
  { pattern: /\bshutil\.rmtree\s*\(/i, label: "shutil.rmtree() (in interpreter one-liner)" },
  { pattern: /\bos\.(?:remove|unlink|removedirs|rmdir)\s*\(/i, label: "os.remove/unlink() (in interpreter one-liner)" },
  { pattern: /\b(?:fs|require\(['"]fs['"]\))\.(?:rmSync|unlinkSync|rmdirSync|rm)\s*\(/i, label: "fs.rmSync/unlinkSync() (in interpreter one-liner)" },
];

// Tokenize the command roughly the way a shell would (respect single/double quotes) so we can find
// the code argument that follows -c / -e without being fooled by spaces inside the quoted payload.
function tokenize(s) {
  const out = [];
  const re = /"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|(\S+)/g;
  let m;
  while ((m = re.exec(s)) !== null) {
    out.push(m[1] !== undefined ? m[1] : m[2] !== undefined ? m[2] : m[3]);
  }
  return out;
}

// cc-safety-net's extractInterpreterCodeArg: the arg after -c / -e, or after a combined short flag
// that contains c/e (e.g. python -Sc "..."). Returns the raw code string, or null.
function extractInterpreterCode(tokens) {
  for (let i = 1; i < tokens.length; i++) {
    const t = tokens[i];
    if (!t) continue;
    if ((t === "-c" || t === "-e") && tokens[i + 1] != null) return tokens[i + 1];
    if (
      t.startsWith("-") && !t.startsWith("--") &&
      (t.includes("c") || t.includes("e")) && tokens[i + 1] != null
    ) {
      return tokens[i + 1];
    }
  }
  return null;
}

for (const { pattern, label } of dangerous) {
  if (pattern.test(cmd)) {
    console.error(
      `Blocked destructive command (${label}): ${cmd.slice(0, 120)}. ` +
        `If this is intended, ask the user to run it manually or temporarily disable the block-dangerous-bash hook.`,
    );
    process.exit(2);
  }
}

if (INTERP.test(cmd)) {
  const code = extractInterpreterCode(tokenize(cmd));
  if (code) {
    for (const { pattern, label } of DANGEROUS_IN_CODE) {
      if (pattern.test(code)) {
        console.error(
          `Blocked destructive command (${label}): ${cmd.slice(0, 120)}. ` +
            `A destructive operation was hidden inside a python -c / node -e style one-liner. ` +
            `If this is intended, ask the user to run it manually or temporarily disable the block-dangerous-bash hook.`,
        );
        process.exit(2);
      }
    }
  }
}
process.exit(0);
