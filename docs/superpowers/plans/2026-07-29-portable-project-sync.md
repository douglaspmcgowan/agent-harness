# Portable Project Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `source-command-subagent-driven-development` or `source-command-executing-plans` task by task. Every behavioral change follows test-driven development.

**Goal:** Rebuild another computer from GitHub-managed projects, a harness-only Capsule with safe Obsidian configuration, and unattended value-safe secret injection.

**Architecture:** GitHub topics provide the dynamic repository catalog. Project data stays behind the transport named in each repository’s `data-manifest.yaml`. Capsule restores the shared harness and an allowlisted Obsidian configuration without carrying project snapshots. Bitwarden Secrets Manager injects approved variables into exact commands through a machine-token broker.

**Tech Stack:** PowerShell 5.1, Git/GitHub CLI, Bitwarden `bws`, Windows Credential Manager or DPAPI, JSON/YAML manifests, Pester-style script fixtures.

---

## File seams

- `.agents/tools/Sync-AgentRepositories.ps1`: repository catalog input → per-repository `clone`, `pull`, or `attention` result.
- `.agents/tools/Sync-AgentRepositories.test.ps1`: fixture GitHub catalog and disposable repositories → deterministic action assertions.
- `.agents/capsule/Refresh-Capsule.ps1`: harness source plus safe configuration → global-only Capsule.
- `.agents/capsule/Bootstrap-Capsule.ps1`: verified Capsule → shared harness and optional Obsidian configuration.
- `.agents/tools/Export-ObsidianConfig.ps1`: active or explicit vault → allowlisted portable configuration.
- `.agents/tools/Restore-ObsidianConfig.ps1`: portable configuration plus explicit/active vault → backed-up configuration update.
- `.agents/tools/Invoke-WithBitwardenSecrets.ps1`: approved command tuple plus token provider → child process environment.
- `.agents/hooks/task-dispatcher.js`: prompt/task state → mutation allowed or blocked when question coverage is absent.

### Task 1: Dynamic repository synchronization

**Files:** create the sync tool and its fixture test; update the project bootstrap/manifests only when required.

- [ ] Write a failing test with missing, clean, dirty, wrong-remote, and non-repository targets.
- [ ] Verify RED because the sync tool does not exist.
- [ ] Implement GitHub topic discovery through `gh repo list --topic agent-project --source --no-archived`.
- [ ] Implement dry-run by default and `-Apply` for clone or `git pull --ff-only`.
- [ ] Refuse to overwrite dirty, ahead, diverged, wrong-remote, or non-repository folders.
- [ ] Verify GREEN and a disposable real clone/pull flow.
- [ ] Commit the coherent task.

### Task 2: Global-only Capsule

**Files:** modify Refresh, Bootstrap, Verify, Capsule tests, templates, and entry instructions.

- [ ] Rewrite the Capsule fixture first to require no workspace/project/application-data payload.
- [ ] Verify RED against the current snapshot-based implementation.
- [ ] Make snapshot input optional and remove all project snapshot copying and restore calls.
- [ ] Package only the harness, tools needed to install it, manifests, and approved Obsidian configuration.
- [ ] Make Bootstrap install the harness, then invoke repository synchronization separately.
- [ ] Verify GREEN, long-path safety, containment, integrity, and alternate-profile restore.
- [ ] Commit the coherent task.

### Task 3: Obsidian configuration portability

**Files:** create exporter/restorer tests and tools; update software manifest.

- [ ] Write failing fixtures containing approved files and poisoned workspace, sync, cache, and plugin-data files.
- [ ] Verify RED because the exporter/restorer do not exist.
- [ ] Allow `app.json`, `appearance.json`, `core-plugins.json`, `hotkeys.json`, `graph.json`, `types.json`, `community-plugins.json`, snippet CSS, and theme manifest/CSS.
- [ ] Exclude workspace, bookmarks, sync, plugin data/runtime, caches, credentials, and vault content.
- [ ] Back up an existing target configuration before restoration.
- [ ] Verify GREEN with explicit and active-vault resolution fixtures.
- [ ] Commit the coherent task.

### Task 4: Unattended Secrets Manager broker

**Files:** create broker test/tool; extend exact command policy and Docket manifest.

- [ ] Write failing tests for exact tuple matching, prefix mapping, missing token, unknown secret, argument changes, output redaction, and child exit propagation.
- [ ] Verify RED because the Secrets Manager broker does not exist.
- [ ] Retrieve one machine token from a protected token provider without printing it.
- [ ] Map prefixed Bitwarden secret names to temporary child-process environment variables.
- [ ] Permit only policy-declared executable, script, fixed arguments, working directory, and variable names.
- [ ] Clear temporary process state after execution.
- [ ] Verify GREEN with a fake `bws` executable and canary values that never appear in output.
- [ ] Commit the coherent task.

### Task 5: Question-ledger enforcement

**Files:** extend the existing task dispatcher and governance tests; append a value-free correction record.

- [ ] Add a failing fixture with multiple questions, an incomplete `TASK.md` answer ledger, and a mutating tool attempt.
- [ ] Verify RED because current hooks only remind.
- [ ] Block the mutation until every recorded question ID has a nonempty answer or an explicit human-required marker.
- [ ] Preserve read-only inspection while the ledger is incomplete.
- [ ] Verify GREEN across Claude, Codex, and Cursor projections where the hook surface exists.
- [ ] Record the reproduced ordering failure and enforcement owner with `Record-Correction.ps1`.
- [ ] Commit the coherent task.

### Task 6: Documentation and installation

**Files:** update `.agents/MAP.md`, the single human README and HTML mirror, Capsule instructions, changelog, manifests, and setup stamp.

- [ ] Replace stale `HARNESS-MAP.md` and `CROSS-AGENT-CONTRACT.md` references with current `MAP.md` and `AGENTS.md`.
- [ ] Explain Git clone/pull/push, data transports, regeneration, object backup, secret bootstrap, and sandbox permissions once.
- [ ] Regenerate the HTML mirror from the Markdown authority.
- [ ] Install globally without replacing product-owned Codex rules.
- [ ] Commit the coherent task.

### Task 7: Completion audit

- [ ] Run every focused test from Tasks 1–5.
- [ ] Run `Test-HarnessSetup.ps1`, `Manage-Harness.test.ps1`, Capsule portability, Gitleaks, and `git diff --check`.
- [ ] Run an adversarial review against every requirement in `TASK.md`.
- [ ] Fix every Critical or Important finding and rerun affected verification.
- [ ] Merge, push, install the exact pushed state, and verify the installed global harness.
- [ ] Leave only provider/account actions that require human authentication.
