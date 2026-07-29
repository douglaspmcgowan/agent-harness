#!/usr/bin/env node
'use strict';
// SessionStart: inject boot context for the session's RESOLVED PROJECT (via hook-state.js) — never the
// workspace-root bare files and never a machine-global task list, so two projects in one folder don't
// cross-inject each other's state.
//   - this session's CURRENT-TASK.<sid>.md (if any)
//   - the project's STATUS.md / LOG.md / BACKGROUND-TASKS.md (project-scoped state dir, then member dirs)
//   - the nearest AGENTS.md walking up from cwd (project or workspace map)
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

(function () {
  const input = S.readStdin();
  const cwd = S.cwdOf(input);
  const proj = S.resolveProject(input);
  const reg = proj.reg;
  const memberDirs = (reg && reg.projects && reg.projects[proj.id] && reg.projects[proj.id].dirs) || [];

  const sections = [];
  const add = (label, p) => {
    try { if (p && fs.existsSync(p)) { const c = fs.readFileSync(p, 'utf8').trim(); if (c) sections.push(`## ${label}\n${c}`); } } catch (_) {}
  };
  // first existing of: project state dir, then each member dir
  const projFile = (name) => {
    const cands = [S.stateDirOf(proj) + '/' + name, S.legacyStateDirOf(proj) + '/' + name, ...memberDirs.map(d => proj.root + '/' + d + '/' + name)];
    for (const c of cands) if (S.exists(c)) return c;
    return null;
  };
  // nearest AGENTS.md walking up from cwd
  const nearestAgents = () => {
    let dir = cwd;
    for (let i = 0; i < 24 && dir && dir.length >= proj.root.length; i++) {
      const p = dir + '/AGENTS.md';
      if (S.exists(p)) return p;
      const parent = S.norm(path.dirname(dir));
      if (parent === dir) break;
      dir = parent;
    }
    return null;
  };

  // 1) this session's task
  add(`CURRENT-TASK (this session, project ${proj.id})`, S.firstExisting(S.sessionDocCandidates(input, 'CURRENT-TASK')));
  // 2) project durable state
  add(`STATUS.md (project ${proj.id})`, projFile('STATUS.md'));
  const logp = projFile('LOG.md');
  if (logp) {
    try {
      const lines = fs.readFileSync(logp, 'utf8').split(/\r?\n/).filter(Boolean);
      const tail = lines.slice(-10).join('\n');
      if (tail) sections.push(`## LOG.md — last ${Math.min(10, lines.length)} (project ${proj.id})\n${tail}`);
    } catch (_) {}
  }
  add(`BACKGROUND-TASKS.md (project ${proj.id})`, projFile('BACKGROUND-TASKS.md'));
  // 3) nearest project / workspace map
  add('AGENTS.md', nearestAgents());

  // ---- harness self-checks (warn loudly at boot; never throw, never block) ----
  // Catches the silent failure modes: an inSync/OneDrive reconcile rolling a hook back to an older version, a stale
  // kill-switch sentinel leaving keep-going INERT, and a plugin update re-arming ralph's Stop hook. Env seams
  // (CLAUDE_HOOKS_DIR / CLAUDE_RALPH_HOOKS) exist only so the test can point these at fixtures.
  const warnings = [];
  try {
    const hooksDir = process.env.CLAUDE_HOOKS_DIR || __dirname;
    // (a) hook-file drift / rollback: a reverted hook loses its current-version marker string
    const markers = [['keep-going.js', ['R14', 'recentAssistantText']], ['hook-state.js', ['resolveProject']], ['wait-on-usage-limit.js', ['STALE_MS']]];
    const markerFiles = new Set(markers.map(m => m[0]));
    for (const [f, subs] of markers) {
      let src = null; try { src = fs.readFileSync(path.join(hooksDir, f), 'utf8'); } catch (_) {}
      if (src == null) warnings.push('hook MISSING: ' + f + ' — keep-going/usage-wait may be broken (inSync/OneDrive deletion?). Restore from git.');
      else { const miss = subs.filter(s => !src.includes(s)); if (miss.length) warnings.push('hook ROLLED BACK?: ' + f + ' lacks [' + miss.join(', ') + '] — looks like an older version (inSync reconcile?). Re-sync from git.'); }
    }
    // (a2) broader sweep: EVERY hook .js wired in settings.json, not just the 3 keep-going-
    // family files above — catches exactly the 2026-07-02 sweep's finding: check-secret-
    // exposure.js silently vanished for ~14 min across 6 concurrent sessions with zero warning
    // anywhere, because nothing checked security-relevant hooks OTHER than keep-going's own
    // family. A missing file here means that hook has been silently non-functional.
    const settingsPaths = process.env.CLAUDE_SETTINGS_PATHS
      ? process.env.CLAUDE_SETTINGS_PATHS.split(path.delimiter)
      : [path.join(hooksDir, '..', 'settings.json')];
    const wiredJs = new Set();
    for (const sp of settingsPaths) {
      let cfg; try { cfg = JSON.parse(fs.readFileSync(sp, 'utf8')); } catch (_) { continue; }
      for (const groups of Object.values(cfg.hooks || {}))
        for (const g of groups || [])
          for (const h of g.hooks || []) {
            const m = (h.command || '').match(/([A-Za-z0-9_-]+\.js)\b/);
            if (m) wiredJs.add(m[1]);
          }
    }
    for (const name of wiredJs) {
      if (markerFiles.has(name)) continue; // already covered above, more precisely
      if (!fs.existsSync(path.join(hooksDir, name))) warnings.push('hook MISSING: ' + name + ' (wired in settings.json) — silently non-functional right now. Restore from git.');
    }
    // (a3) allow-list narrowing check (2026-07-02 sweep: "why did you have to ask for permission
    // to create need user? i think you've made that stuff before" - the allow-list had silently
    // shrunk between sessions with no signal anywhere). Snapshots permissions.allow across all
    // settings.json paths and warns if a rule present last time is gone now.
    try {
      const snapPath = process.env.CLAUDE_PERMISSIONS_SNAPSHOT || path.join(__dirname, '..', '.permissions-snapshot.json');
      const currentAllow = new Set();
      for (const sp of settingsPaths) {
        let cfg; try { cfg = JSON.parse(fs.readFileSync(sp, 'utf8')); } catch (_) { continue; }
        for (const rule of (cfg.permissions && cfg.permissions.allow) || []) currentAllow.add(rule);
      }
      let prevAllow = null;
      try { prevAllow = JSON.parse(fs.readFileSync(snapPath, 'utf8')); } catch (_) {}
      if (Array.isArray(prevAllow)) {
        const lost = prevAllow.filter(r => !currentAllow.has(r));
        if (lost.length) warnings.push('allow-list NARROWED since last session — lost: ' + lost.join(', '));
      }
      fs.writeFileSync(snapPath, JSON.stringify([...currentAllow]));
    } catch (_) {}
    // (b) stale kill-switch sentinel: keep-going is silently INERT for this session until removed
    for (const flag of ['.stop-autorun', '.no-keepgoing', '.need-user']) {
      const f = S.firstExisting(S.sessionFlagCandidates(input, flag));
      if (f) warnings.push('kill switch ACTIVE: ' + flag + '.<sid> exists -> keep-going will NOT drive this session. Remove to re-arm: ' + f);
    }
    // (c) ralph-loop plugin Stop hook re-armed (a plugin update could restore a 2nd Stop voter)
    try {
      const rp = process.env.CLAUDE_RALPH_HOOKS || path.join(__dirname, '..', 'plugins', 'marketplaces', 'claude-plugins-official', 'plugins', 'ralph-loop', 'hooks', 'hooks.json');
      const rj = JSON.parse(fs.readFileSync(rp, 'utf8'));
      if (rj && rj.hooks && Object.keys(rj.hooks).length) warnings.push('ralph-loop hooks.json was RE-ARMED (plugin update?) -> a 2nd Stop voter competes with keep-going. Re-empty its "hooks" to {}.');
    } catch (_) {}
    // (d) ARMED vs INERT report — the self-check that an autonomous run is actually wired
    let actionable = 0;
    for (const base of ['WORK_QUEUE', 'CURRENT-TASK']) {
      const qf = S.firstExisting(S.sessionDocCandidates(input, base));
      if (qf) { try { actionable += (fs.readFileSync(qf, 'utf8').match(/^\s*(?:[-*+]|\d+[.)])\s*\[[ ~]\]/gm) || []).length; } catch (_) {} }
    }
    const inertBySentinel = warnings.some(w => w.startsWith('kill switch ACTIVE'));
    sections.unshift('## keep-going loop\n' + (actionable > 0 && !inertBySentinel
      ? 'ARMED — ' + actionable + ' actionable item(s) queued for this session; autonomous continue is ON.'
      : 'INERT — ' + (inertBySentinel ? 'a kill-switch sentinel is present (see self-check); ' : 'no actionable queue items; ') + 'autonomous continue is OFF.'));
  } catch (_) {}
  if (warnings.length) sections.unshift('## ⚠ harness self-check\n- ' + warnings.join('\n- '));

  if (sections.length === 0) return;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext: `Session boot context (project: ${proj.id}, via ${proj.via}):\n\n${sections.join('\n\n')}`,
    },
  }));
})();
