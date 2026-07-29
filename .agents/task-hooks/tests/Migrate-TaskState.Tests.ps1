[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\Migrate-TaskState.ps1'
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('task-hook-migrate-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    @'
# Current Task

## Goal

Consolidate the harness task files.

## Completed

- [x] Audited the old hook wiring.

## Remaining

1. [ ] Build the migration.
2. Run the tests.

## Next verifier

Run the staged test suite.
'@ | Set-Content -LiteralPath (Join-Path $temp 'CURRENT-TASK.md') -Encoding utf8

    @'
# Work queue

## Earlier

- [x] Historical completed item.
- [!] Waiting for a credential.

## Current

- [ ] Build the migration.
- [~] Stage the hook dispatcher.
- [?] Choose a deployment window.
'@ | Set-Content -LiteralPath (Join-Path $temp 'WORK_QUEUE.md') -Encoding utf8

    @'
# Verification

Run the staged test suite and confirm the deployment verifier accepts the repository.
'@ | Set-Content -LiteralPath (Join-Path $temp 'VERIFY.md') -Encoding utf8

    & $script -Repository $temp

    $taskPath = Join-Path $temp 'TASK.md'
    $first = Get-Content -Raw -LiteralPath $taskPath
    if ($first -notmatch 'Consolidate the harness task files') { throw 'Goal was not preserved.' }
    if (($first | Select-String -Pattern '\[ \] Build the migration\.' -AllMatches).Matches.Count -ne 1) {
        throw 'Duplicate open task was not consolidated.'
    }
    foreach ($needle in @(
        '- [~] Stage the hook dispatcher.',
        '- [!] Waiting for a credential.',
        '- [?] Choose a deployment window.',
        '- [x] Audited the old hook wiring.',
        'Run the staged test suite.'
    )) {
        if (-not $first.Contains($needle)) { throw "Missing migrated content: $needle" }
    }
    if ($first.Contains('- [x] Historical completed item.')) {
        throw 'Historical queue completion was copied into concise TASK.md.'
    }
    $archivedQueue = Join-Path $temp '.agents\archive\task-state-migration\WORK_QUEUE.md'
    if (-not (Test-Path -LiteralPath $archivedQueue)) { throw 'WORK_QUEUE.md was not archived.' }
    if (-not ([System.IO.File]::ReadAllText($archivedQueue).Contains('- [x] Historical completed item.'))) {
        throw 'Archived WORK_QUEUE.md lost historical completion evidence.'
    }
    $archivedVerify = Join-Path $temp '.agents\archive\task-state-migration\VERIFY.md'
    if (-not (Test-Path -LiteralPath $archivedVerify)) { throw 'VERIFY.md was not archived.' }
    if (-not $first.Contains('.agents/archive/task-state-migration/VERIFY.md')) {
        throw 'TASK.md does not point to the archived verification contract.'
    }
    foreach ($legacyName in @('CURRENT-TASK.md', 'WORK_QUEUE.md', 'VERIFY.md')) {
        if (Test-Path -LiteralPath (Join-Path $temp $legacyName)) {
            throw "Legacy root file still blocks deployment: $legacyName"
        }
    }
    $logPath = Join-Path $temp 'LOG.md'
    $log = [System.IO.File]::ReadAllText($logPath)
    if (-not $log.Contains('Task state consolidated into TASK.md')) {
        throw 'LOG.md does not record where historical task state was retained.'
    }

    & $script -Repository $temp
    $second = Get-Content -Raw -LiteralPath $taskPath
    if ($first -cne $second) { throw 'Migration is not idempotent.' }
    $logAfterSecondRun = [System.IO.File]::ReadAllText($logPath)
    if (($logAfterSecondRun | Select-String -Pattern 'Task state consolidated into TASK.md' -AllMatches).Matches.Count -ne 1) {
        throw 'Migration LOG.md record was duplicated.'
    }

    # A partially restored legacy file must be removed idempotently using the verified archive as context.
    Copy-Item -LiteralPath $archivedQueue -Destination (Join-Path $temp 'WORK_QUEUE.md')
    & $script -Repository $temp
    if (Test-Path -LiteralPath (Join-Path $temp 'WORK_QUEUE.md')) {
        throw 'A restored legacy WORK_QUEUE.md was not cleared.'
    }
    if ((Get-Content -Raw -LiteralPath $taskPath) -cne $first) {
        throw 'Partial-rerun recovery changed TASK.md.'
    }

    Write-Output 'Migrate-TaskState tests passed'
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}
