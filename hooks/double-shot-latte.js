#!/usr/bin/env node
/**
 * Double Shot Latte — Stop hook that calls a judge LLM to decide if the user
 * is actually needed. If not, it auto-resumes (by exiting with code 2 and
 * writing a "keep going" reason to stderr).
 *
 * Implementation choice (Option C from session 2026-05-08): use the Claude
 * Code CLI itself with --model haiku. No separate Anthropic API key needed
 * (uses your CC subscription auth); cheap (Haiku tokens); reliable.
 *
 * Safety:
 *  - Recursion guard: tracks stop times in /tmp/dsl-stop-history.json; bails
 *    out (allows stop) if 3+ stops in last 5 minutes.
 *  - Hard timeout on the subprocess (8 sec) — if the CLI hangs, allow stop.
 *  - Disabled when stop_hook_active flag is present (re-entrant stop).
 *  - Skips the judge if there's an open CURRENT-TASK.md AND the last
 *    assistant message ended with a clear question to the user.
 *  - Never auto-resumes after a destructive operation (git push --force, rm,
 *    deploys) — looks for these in the transcript and bails.
 *
 * Cost expectation: ~150 input tokens + ~50 output tokens per Stop event,
 * via Haiku — pennies per session.
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync, spawnSync } = require("child_process");

const STATE_FILE = path.join(os.tmpdir(), "dsl-stop-history.json");
const RECURSION_WINDOW_MS = 5 * 60 * 1000;
const RECURSION_LIMIT = 3;
const JUDGE_TIMEOUT_MS = 8 * 1000;

const DESTRUCTIVE_PATTERNS = [
  /git\s+push\s+--force/i,
  /rm\s+-rf/i,
  /vercel\s+--prod/i,
  /npm\s+publish/i,
  /git\s+reset\s+--hard/i,
  /DROP\s+TABLE/i,
  /DELETE\s+FROM/i,
];

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
    return { stops: [] };
  }
}

function saveState(state) {
  try {
    fs.writeFileSync(STATE_FILE, JSON.stringify(state));
  } catch {}
}

function tooManyRecentStops(state) {
  const now = Date.now();
  const recent = state.stops.filter((t) => now - t < RECURSION_WINDOW_MS);
  state.stops = recent;
  return recent.length >= RECURSION_LIMIT;
}

function lastAssistantMessageContainsQuestion(transcript) {
  if (!Array.isArray(transcript)) return false;
  for (let i = transcript.length - 1; i >= 0; i--) {
    const msg = transcript[i];
    if (msg.role === "assistant") {
      const text =
        typeof msg.content === "string"
          ? msg.content
          : Array.isArray(msg.content)
            ? msg.content.map((c) => c.text || "").join(" ")
            : "";
      // Heuristic: ends with a question mark within last 200 chars,
      // or contains common "ask user" phrasings.
      const tail = text.slice(-300);
      if (/\?\s*$/.test(tail.trim())) return true;
      if (
        /(do you want|should i|let me know|which would|please confirm|please clarify)/i.test(
          tail,
        )
      )
        return true;
      return false;
    }
  }
  return false;
}

function transcriptContainsDestructive(transcript) {
  if (!Array.isArray(transcript)) return false;
  // Check the last few messages only — old destructive ops don't matter.
  const last = transcript.slice(-6);
  for (const msg of last) {
    const text =
      typeof msg.content === "string"
        ? msg.content
        : Array.isArray(msg.content)
          ? msg.content.map((c) => c.text || JSON.stringify(c)).join(" ")
          : "";
    for (const pat of DESTRUCTIVE_PATTERNS) {
      if (pat.test(text)) return true;
    }
  }
  return false;
}

function projectHasOpenTaskFile(cwd) {
  if (!cwd) return false;
  const candidates = [
    path.join(cwd, "CURRENT-TASK.md"),
    path.join(cwd, "..", "CURRENT-TASK.md"),
  ];
  for (const p of candidates) {
    try {
      const content = fs.readFileSync(p, "utf8");
      if (/^\s*-\s*\[\s\]/m.test(content)) return true;
    } catch {}
  }
  return false;
}

function callJudge(transcriptSummary) {
  // Compose a tight prompt for Haiku.
  const judgePrompt = `You are a stop-hook judge. Given the last few turns of a coding session, decide whether the human user genuinely needs to intervene right now, or whether the assistant has work it can continue without input.

Reply with EXACTLY one of:
  CONTINUE: <one short reason>
  STOP: <one short reason>

Reply CONTINUE only if all of: (a) there's clearly more work in flight, (b) no question is pending for the user, (c) no destructive operation was just performed, (d) the assistant's last message looks like a checkpoint/status, not a deliverable. Otherwise reply STOP.

Last few turns:
${transcriptSummary}`;

  try {
    const result = spawnSync(
      process.platform === "win32" ? "claude.cmd" : "claude",
      ["-p", judgePrompt, "--model", "haiku"],
      {
        timeout: JUDGE_TIMEOUT_MS,
        encoding: "utf8",
        windowsHide: true,
      },
    );
    if (result.status !== 0) return null;
    return (result.stdout || "").trim();
  } catch {
    return null;
  }
}

function summarizeTranscript(transcript) {
  if (!Array.isArray(transcript)) return "(no transcript available)";
  const last = transcript.slice(-4);
  return last
    .map((m) => {
      const role = m.role || "?";
      const text =
        typeof m.content === "string"
          ? m.content
          : Array.isArray(m.content)
            ? m.content.map((c) => c.text || "").join(" ")
            : "";
      return `${role}: ${text.slice(0, 600)}`;
    })
    .join("\n---\n");
}

function main() {
  const raw = readStdin();
  let payload = {};
  try {
    payload = JSON.parse(raw || "{}");
  } catch {}

  // Don't run during re-entrant stop
  if (payload.stop_hook_active) {
    process.exit(0);
  }

  const cwd = payload.cwd || process.cwd();
  const transcript = payload.transcript || payload.messages || [];

  // Bail-outs that always allow stop
  if (lastAssistantMessageContainsQuestion(transcript)) {
    process.exit(0);
  }
  if (transcriptContainsDestructive(transcript)) {
    process.exit(0);
  }

  // Recursion guard
  const state = loadState();
  if (tooManyRecentStops(state)) {
    saveState(state);
    process.exit(0);
  }

  // Only fire judge if there's an open task — otherwise just allow stop
  if (!projectHasOpenTaskFile(cwd)) {
    process.exit(0);
  }

  // Call the judge
  const summary = summarizeTranscript(transcript);
  const verdict = callJudge(summary);

  if (!verdict) {
    // Judge failed — default to allowing stop (safer)
    process.exit(0);
  }

  // Record this stop attempt for recursion-guard tracking
  state.stops.push(Date.now());
  saveState(state);

  if (/^CONTINUE\b/i.test(verdict)) {
    const reason =
      verdict.replace(/^CONTINUE:\s*/i, "").trim() ||
      "judge says more work to do";
    // Exit code 2 + stderr message tells Claude Code to inject a continuation.
    console.error(
      `Auto-resuming via Double Shot Latte (Haiku judge): ${reason}\n` +
        `Continue from CURRENT-TASK.md remaining steps. If this resume was wrong, reply STOP.`,
    );
    process.exit(2);
  }

  // STOP or unrecognized → allow stop
  process.exit(0);
}

main();
