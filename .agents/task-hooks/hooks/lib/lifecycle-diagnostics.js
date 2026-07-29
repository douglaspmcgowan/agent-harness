'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const WINDOW_MS = 15 * 60 * 1000;
const TAIL_BYTES = 300 * 1024;

function tail(file) {
  let stats;
  try { stats = fs.statSync(file); } catch (_) { return ''; }
  try {
    const length = Math.min(stats.size, TAIL_BYTES);
    const buffer = Buffer.alloc(length);
    const descriptor = fs.openSync(file, 'r');
    fs.readSync(descriptor, buffer, 0, length, stats.size - length);
    fs.closeSync(descriptor);
    return buffer.toString('utf8');
  } catch (_) {
    return '';
  }
}

function recentHookTimeouts(input) {
  const content = tail(String(input.transcript_path || ''));
  const cutoff = Date.now() - WINDOW_MS;
  const hits = new Set();
  for (const line of content.split(/\r?\n/)) {
    if (!line.includes('"hook_cancelled"') || !line.includes('"timedOut":true')) continue;
    let record;
    try { record = JSON.parse(line); } catch (_) { continue; }
    if (record.timestamp && Date.parse(record.timestamp) < cutoff) continue;
    const attachment = record.attachment;
    if (!attachment || attachment.type !== 'hook_cancelled' || !attachment.timedOut) continue;
    const name = path.basename(String(attachment.command || attachment.hookName || ''));
    if (/security-dispatch|task-state-dispatch|continue-dispatch|block-secret-dump|check-secret-exposure|block-dangerous-bash/i.test(name)) {
      hits.add(name);
    }
  }
  if (!hits.size) return null;
  return `Harness hook timeout detected in the last 15 minutes: ${[...hits].join(', ')}. ` +
    `The affected guard did not complete; surface the event and verify the associated action.`;
}

function recentStopFailures(input) {
  const content = tail(String(input.transcript_path || ''));
  const cutoff = Date.now() - WINDOW_MS;
  const hits = new Set();
  for (const line of content.split(/\r?\n/)) {
    if (!line.includes('"hookErrors":[') || line.includes('"hookErrors":[]')) continue;
    let record;
    try { record = JSON.parse(line); } catch (_) { continue; }
    if (record.timestamp && Date.parse(record.timestamp) < cutoff) continue;
    for (const error of Array.isArray(record.hookErrors) ? record.hookErrors : []) {
      if (typeof error !== 'string' || /^\[.*\]:\s*KEEP GOING/.test(error)) continue;
      if (/^Failed to run:|^Failed with non-blocking status code:/.test(error)) hits.add(error);
    }
  }
  if (!hits.size) return null;
  return `${hits.size} Stop-hook execution failure(s) occurred in the last 15 minutes. ` +
    `Continuation failed open; surface the failure and inspect process pressure before resuming unattended work.`;
}

const SKILL_ROUTES = [
  ['source-command-systematic-debugging', /\b(bug|broken|crash(?:es|ed|ing)?|fails?|failing|unexpected|why (?:did|does|is))\b/i],
  ['source-command-brainstorming', /\b(build|create|add)\b.{0,40}\b(feature|component|tool|app|dashboard|workflow)\b/i],
  ['impeccable', /\b(redesign|UI|UX|layout|typography|looks? (?:bad|wrong|off)|design review)\b/i],
  ['source-command-parallelize', /\b(parallelize|in parallel|side agents?|subagents?)\b/i],
  ['deep-search', /\b(research|recon|find current|what do (?:users|people) say|best practice)\b/i],
  ['source-command-verification-before-completion', /\b(verify|prove|test everything|confirm .* works)\b/i],
  ['correct', /\b(recurring error|never do this again|durable correction|keep making)\b/i],
  ['source-command-task', /\b(parse|intake|track)\b.{0,30}\b(tasks?|prompt|requests?)\b/i],
];

function recentSkillInvocation(input) {
  const content = tail(String(input.transcript_path || ''));
  const cutoff = Date.now() - WINDOW_MS;
  for (const line of content.split(/\r?\n/)) {
    if (!line.includes('"name":"Skill"') && !line.includes('"name": "Skill"')) continue;
    let record;
    try { record = JSON.parse(line); } catch (_) { continue; }
    if (record.timestamp && Date.parse(record.timestamp) < cutoff) continue;
    const blocks = record.message && record.message.content;
    if (Array.isArray(blocks) && blocks.some(block => block && block.type === 'tool_use' && block.name === 'Skill')) {
      return true;
    }
  }
  return false;
}

function skillNudge(input) {
  const prompt = String(input.prompt || input.user_prompt || '');
  const route = SKILL_ROUTES.find(([, pattern]) => pattern.test(prompt));
  if (!route || recentSkillInvocation(input)) return null;
  return `Prompt signal matches the installed ${route[0]} workflow. Check that skill before implementation and ` +
    `record a brief reason when it does not apply.`;
}

function appendPromptTelemetry(input, state) {
  const prompt = String(input.prompt || input.user_prompt || '');
  const sid = state.sessionId(input);
  if (!prompt.trim() || !sid) return null;
  const project = state.resolveProject(input);
  const file = path.join(state.stateDir(project), `PROMPT_TELEMETRY.${sid}.md`);
  const route = SKILL_ROUTES.find(([, pattern]) => pattern.test(prompt));
  const pathways = pathwaySignals(prompt);
  const fields = [
    `- skill-route: ${route ? route[0] : 'none'}`,
    `- pathway-flags: ${pathways.length ? pathways.join(', ') : 'none'}`,
    '- task-reconciliation-required: true',
  ];
  try {
    state.ensureDir(path.dirname(file));
    fs.appendFileSync(file, `\n## ${new Date().toISOString()}\n${fields.join('\n')}\n`, 'utf8');
    return file;
  } catch (_) {
    return null;
  }
}

function pathwayFile() {
  if (process.env.HARNESS_SKILL_PATHWAYS) return process.env.HARNESS_SKILL_PATHWAYS;
  const candidates = [
    path.join(os.homedir(), '.agents', 'skill-pathways.json'),
    path.join(os.homedir(), '.claude', 'hooks', 'skill-pathways.json'),
  ];
  return candidates.find(file => fs.existsSync(file)) || null;
}

function stepPattern(step) {
  return new RegExp(`\\b${String(step).replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/-/g, '[-\\s]?')}\\b`, 'i');
}

function pathwaySignals(prompt) {
  const source = pathwayFile();
  if (!source) return [];
  let chains;
  try {
    const parsed = JSON.parse(fs.readFileSync(source, 'utf8'));
    chains = Array.isArray(parsed.chains) ? parsed.chains : [];
  } catch (_) {
    return [];
  }
  return chains
    .filter(chain => {
      const steps = Array.isArray(chain.steps) ? chain.steps.map(String) : [];
      return steps.filter(step => stepPattern(step).test(prompt)).length >= Number(chain.minNamedToTrigger || 2);
    })
    .map(chain => String(chain.id || chain.name || 'chain').replace(/[^A-Za-z0-9_-]/g, ''))
    .filter(Boolean);
}

function pathwayNudge(input, state) {
  const prompt = String(input.prompt || input.user_prompt || '');
  const source = pathwayFile();
  if (!prompt.trim() || !source) return null;
  let chains;
  try {
    const parsed = JSON.parse(fs.readFileSync(source, 'utf8'));
    chains = Array.isArray(parsed.chains) ? parsed.chains : [];
  } catch (_) {
    return null;
  }
  for (const chain of chains) {
    const steps = Array.isArray(chain.steps) ? chain.steps.map(String) : [];
    const named = steps.filter(step => stepPattern(step).test(prompt));
    if (named.length < Number(chain.minNamedToTrigger || 2)) continue;
    const marker = state && state.sessionId(input)
      ? state.sessionFlagWrite(input, `.pathway-nudge.${String(chain.id || 'chain').replace(/[^A-Za-z0-9_-]/g, '')}`)
      : null;
    if (marker && fs.existsSync(marker)) continue;
    if (marker) {
      try {
        state.ensureDir(path.dirname(marker));
        fs.writeFileSync(marker, new Date().toISOString(), 'utf8');
      } catch (_) {}
    }
    return `This prompt names ${named.length} steps from the ${chain.name || chain.id || 'skill'} pathway ` +
      `(${steps.join(' → ')}). Check the remaining steps before finishing.`;
  }
  return null;
}

function approvalFiles(input, state) {
  const sid = state.sessionId(input);
  if (!sid) return [];
  const name = `.longrun-needs-approval.${sid}.md`;
  const project = state.resolveProject(input);
  return [path.join(state.stateDir(project), name), path.join(project.root, name)];
}

function surfaceNeedsApproval(input, state) {
  const file = approvalFiles(input, state).find(state.exists);
  if (!file) return null;
  let content;
  try { content = fs.readFileSync(file, 'utf8').trim(); } catch (_) { return null; }
  if (!content) return null;
  try {
    fs.appendFileSync(file.replace(/\.md$/, '.SURFACED.md'), `\n---- surfaced ${new Date().toISOString()} ----\n${content}\n`);
    fs.unlinkSync(file);
  } catch (_) {}
  return `Unattended work recorded items needing a user decision:\n\n${content}`;
}

function configuredCommands(config) {
  const commands = [];
  for (const groups of Object.values((config && config.hooks) || {})) {
    for (const group of Array.isArray(groups) ? groups : []) {
      if (group.command) commands.push(String(group.command));
      for (const hook of Array.isArray(group.hooks) ? group.hooks : []) {
        if (hook.command) commands.push(String(hook.command));
      }
    }
  }
  return commands;
}

function sessionSelfChecks(input, state) {
  const warnings = [];
  const hooksDir = process.env.HARNESS_HOOKS_DIR || path.resolve(__dirname, '..');
  for (const name of ['security-dispatch.js', 'task-state-dispatch.js', 'continue-dispatch.js']) {
    if (!fs.existsSync(path.join(hooksDir, name))) warnings.push(`required hook missing: ${name}`);
  }

  const configPaths = process.env.HARNESS_PRODUCT_CONFIGS
    ? process.env.HARNESS_PRODUCT_CONFIGS.split(path.delimiter)
    : [
        path.join(os.homedir(), '.claude', 'settings.json'),
        path.join(os.homedir(), '.codex', 'hooks.json'),
        path.join(os.homedir(), '.cursor', 'hooks.json'),
      ];
  const allowed = new Set(['security-dispatch.js', 'task-state-dispatch.js', 'continue-dispatch.js']);
  const currentPermissions = new Set();
  for (const configPath of configPaths) {
    let config;
    try {
      config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch (_) {
      if (fs.existsSync(configPath)) warnings.push(`product hook config could not be parsed: ${configPath}`);
      continue;
    }
    for (const command of configuredCommands(config)) {
      for (const match of command.matchAll(/([A-Za-z0-9_.-]+\.js)\b/g)) {
        if (/-dispatch\.js$/i.test(match[1]) && !allowed.has(match[1])) {
          warnings.push(`unexpected dispatcher wired in ${configPath}: ${match[1]}`);
        }
      }
    }
    for (const rule of (config.permissions && config.permissions.allow) || []) currentPermissions.add(rule);
  }

  const stateRoot = process.env.HARNESS_STATE_DIR || path.join(os.homedir(), '.agents', 'state');
  const snapshot = path.join(stateRoot, 'permissions-snapshot.json');
  try {
    let previous = [];
    try { previous = JSON.parse(fs.readFileSync(snapshot, 'utf8')); } catch (_) {}
    const lost = Array.isArray(previous) ? previous.filter(rule => !currentPermissions.has(rule)) : [];
    if (lost.length) warnings.push(`permission allow-list narrowed by ${lost.length} rule(s) since the last session`);
    fs.mkdirSync(stateRoot, { recursive: true });
    fs.writeFileSync(snapshot, JSON.stringify([...currentPermissions].sort()), 'utf8');
  } catch (_) {}

  const ralph = process.env.HARNESS_RALPH_HOOKS ||
    path.join(os.homedir(), '.claude', 'plugins', 'marketplaces', 'claude-plugins-official', 'plugins', 'ralph-loop', 'hooks', 'hooks.json');
  try {
    const config = JSON.parse(fs.readFileSync(ralph, 'utf8'));
    if (config.hooks && Object.keys(config.hooks).length) warnings.push('ralph-loop plugin Stop hook is rearmed');
  } catch (_) {}

  for (const flag of ['.need-user', '.stop-autorun', '.no-keepgoing']) {
    if (state.sessionFlagCandidates(input, flag).length) warnings.push(`continuation sentinel active: ${flag}`);
  }
  return warnings;
}

module.exports = {
  tail,
  recentHookTimeouts,
  recentStopFailures,
  recentSkillInvocation,
  skillNudge,
  appendPromptTelemetry,
  pathwaySignals,
  pathwayNudge,
  surfaceNeedsApproval,
  configuredCommands,
  sessionSelfChecks,
};
