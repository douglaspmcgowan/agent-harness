# Portable legacy hook source map

The dispatcher resolves `legacy\<product>\<module>` before `legacy\<module>`. This package uses the
Claude copy for every byte-identical Claude/Codex module and preserves each divergent Cursor module
under `legacy\cursor`.

## Shared modules

Each source below maps from `C:\Users\dougl\.claude\hooks\<name>` to
`C:\Users\dougl\projects\general-claude\harness-updates\task-hooks\hooks\legacy\<name>`.

- `security-checks-fast.js`
- `block-visible-powershell.js`
- `block-secret-dump.js`
- `check-secret-exposure.js`
- `block-dangerous-bash.js`
- `guard-env-mutation.js`
- `guard-bulk-delete.js`
- `protect-security-config.js`
- `protect-authored-docs.js`
- `protect-ai-reference.js`
- `protect-firmware.js`
- `scan-write-for-secrets.js`
- `concurrent-edit-lock.js`
- `block-ai-reference.js`
- `block-sensitive-file-read.js`
- `warn-large-read.js`
- `block-obsidian-delete.js`
- `scan-output-for-secrets.js`
- `audit-bash-log.js`
- `bypass-incident-log.js`
- `format-on-edit.js`
- `auto-schedule-codex-poll.js`
- `impeccable-run-log.js`
- `keep-going.js`
- `hook-state.js`
- `allow-tags.js`
- `gates-config.js`

## Claude modules

Each source below maps from `C:\Users\dougl\.claude\hooks\<name>` to
`C:\Users\dougl\projects\general-claude\harness-updates\task-hooks\hooks\legacy\claude\<name>`.

- `dep-audit-gate.js`
- `test-green-gate.js`
- `gates-config.js` — colocated dependency of both modules

## Codex modules

Codex uses the shared modules. Its required live copies matched the Claude sources byte-for-byte.

## Cursor modules

Each source below maps from `C:\Users\dougl\.cursor\hooks\<name>` to
`C:\Users\dougl\projects\general-claude\harness-updates\task-hooks\hooks\legacy\cursor\<name>`.

- `check-secret-exposure.js`
- `block-dangerous-bash.js`
- `protect-firmware.js`
- `block-obsidian-delete.js`
- `scrub-secrets-from-output.js`
- `format-on-edit.js`
- `auto-schedule-codex-poll.js`
- `check-session-size.js`

## Local dependencies

- `security-checks-fast.js` → `hook-state.js`, `allow-tags.js`
- `block-visible-powershell.js` → `hook-state.js`
- `block-secret-dump.js` → `allow-tags.js`
- `check-secret-exposure.js` → `allow-tags.js`
- `scan-write-for-secrets.js` → `allow-tags.js`
- `concurrent-edit-lock.js` → `hook-state.js`
- `warn-large-read.js` → `hook-state.js`
- `bypass-incident-log.js` → `hook-state.js`
- `impeccable-run-log.js` → `hook-state.js`
- `keep-going.js` → `hook-state.js`
- `legacy\claude\dep-audit-gate.js` → `legacy\claude\gates-config.js`
- `legacy\claude\test-green-gate.js` → `legacy\claude\gates-config.js`

`portable-legacy-modules.test.js` verifies product/shared precedence with
`HARNESS_LEGACY_HOOKS` unset, every dispatcher/config module, every local dependency, and Node syntax
for every packaged JavaScript file.
