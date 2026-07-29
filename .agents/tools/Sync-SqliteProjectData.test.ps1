[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'Sync-SqliteProjectData.ps1'
$helper = Join-Path $PSScriptRoot 'sqlite_project_data.py'
if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
    throw "SQLite project-data tool is missing: $tool"
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Find-RunnablePython {
    foreach ($candidate in @(
        Get-Command python.exe -All -ErrorAction SilentlyContinue
        Get-Command py.exe -All -ErrorAction SilentlyContinue
    )) {
        [string[]]$prefix = if ($candidate.Name -ieq 'py.exe') { @('-3') } else { @() }
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $candidate.Source @prefix -c 'import sqlite3,sys; sys.exit(0)' 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                return [pscustomobject]@{ Source = $candidate.Source; Prefix = [string[]]@($prefix + '-B') }
            }
        }
        catch {}
        finally {
            $ErrorActionPreference = $previousPreference
        }
    }
    return $null
}

$root = Join-Path $env:TEMP ('sqlite-project-data-' + [Guid]::NewGuid().ToString('N'))
try {
    $localRoot = Join-Path $root 'Local Data With Spaces'
    $syncRoot = Join-Path $root 'Google Drive With Spaces\Project Data'
    $database = Join-Path $localRoot 'runtime\app.sqlite3'
    New-Item -ItemType Directory -Path (Split-Path -Parent $database) -Force | Out-Null
    New-Item -ItemType Directory -Path $syncRoot -Force | Out-Null

    $python = Find-RunnablePython
    if (-not $python) {
        Write-Host 'Sync-SqliteProjectData integration skipped because no runnable normal-user Python exists.'
        return
    }
    [string[]]$pythonPrefix = $python.Prefix

    $brokenBin = Join-Path $root 'broken python shim'
    New-Item -ItemType Directory -Path $brokenBin -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $brokenBin 'python.exe'), 'broken shim', [Text.Encoding]::ASCII)
    $priorPath = $env:PATH
    try {
        $env:PATH = $brokenBin + [IO.Path]::PathSeparator + $priorPath
        $probeStatus = & $tool -Action Status -ProjectName 'fixture-project' -DatabasePath $database `
            -LocalDataRoot $localRoot -SyncRoot $syncRoot
        Assert-True ($probeStatus.Action -eq 'Status') 'Python discovery accepted a broken earlier shim instead of a runnable candidate.'
    }
    finally {
        $env:PATH = $priorPath
    }

    $createScript = "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.execute('create table items (id integer primary key, value text not null)'); db.execute('insert into items(value) values (?)', ('first',)); db.commit(); db.close()"
    & $python.Source @pythonPrefix -c $createScript $database
    if ($LASTEXITCODE -ne 0) { throw 'Fixture database creation failed.' }

    $export = & $tool -Action Export -ProjectName 'fixture-project' -DatabasePath $database -LocalDataRoot $localRoot -SyncRoot $syncRoot
    Assert-True ($export.Action -eq 'Export') 'Export did not report its action.'
    Assert-True (Test-Path -LiteralPath $export.SnapshotPath -PathType Leaf) 'Export did not create a SQLite snapshot.'
    Assert-True (Test-Path -LiteralPath $export.ChecksumPath -PathType Leaf) 'Export did not create a checksum.'
    Assert-True (Test-Path -LiteralPath $export.MetadataPath -PathType Leaf) 'Export did not create completion metadata.'
    Assert-True ($export.SnapshotPath.StartsWith((Join-Path $syncRoot 'fixture-project'), [StringComparison]::OrdinalIgnoreCase)) 'Export escaped the project sync root.'
    Assert-True ($export.PruneInventory.Applied -eq $false) 'Export applied retention pruning without an explicit second-phase request.'

    1..4 | ForEach-Object {
        & $tool -Action Export -ProjectName 'prune-project' -DatabasePath $database `
            -LocalDataRoot $localRoot -SyncRoot $syncRoot | Out-Null
    }
    $pruneDryRun = & $tool -Action Prune -ProjectName 'prune-project' -DatabasePath $database `
        -LocalDataRoot $localRoot -SyncRoot $syncRoot
    Assert-True ($pruneDryRun.Applied -eq $false) 'Prune dry-run deleted snapshots without the apply switch.'
    Assert-True (@($pruneDryRun.Delete).Count -eq 3) 'Prune dry-run did not inventory the expired same-day snapshots.'
    $pruneStatus = & $tool -Action Status -ProjectName 'prune-project' -DatabasePath $database `
        -LocalDataRoot $localRoot -SyncRoot $syncRoot
    Assert-True ($pruneStatus.SnapshotCount -eq 4) 'Prune dry-run changed the snapshot set.'
    $pruneApplied = & $tool -Action Prune -ProjectName 'prune-project' -DatabasePath $database `
        -LocalDataRoot $localRoot -SyncRoot $syncRoot -ApplyRetentionPrune
    Assert-True ($pruneApplied.Applied -eq $true) 'Explicit retention prune did not apply the dry-run inventory.'
    Assert-True ($pruneApplied.RestoreVerified -eq $true) 'Explicit retention prune did not report disposable restore proof.'
    $prunedStatus = & $tool -Action Status -ProjectName 'prune-project' -DatabasePath $database `
        -LocalDataRoot $localRoot -SyncRoot $syncRoot
    Assert-True ($prunedStatus.SnapshotCount -eq 1) 'Explicit retention prune did not retain exactly the newest same-day snapshot.'

    $snapshotDirectory = Split-Path -Parent $export.SnapshotPath
    $orphan = Join-Path $snapshotDirectory '99999999T999999Z-orphan.sqlite3'
    [System.IO.File]::WriteAllText($orphan, 'incomplete')
    $orphanStatus = & $tool -Action Status -ProjectName 'fixture-project' -DatabasePath $database -LocalDataRoot $localRoot -SyncRoot $syncRoot
    Assert-True ($orphanStatus.SnapshotCount -eq 1) 'Status treated an incomplete Drive upload as a restorable snapshot.'

    $mutateScript = "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.execute('insert into items(value) values (?)', ('second',)); db.commit(); db.close()"
    & $python.Source @pythonPrefix -c $mutateScript $database
    if ($LASTEXITCODE -ne 0) { throw 'Fixture mutation failed.' }

    $restore = & $tool -Action Restore -ProjectName 'fixture-project' -DatabasePath $database -LocalDataRoot $localRoot -SyncRoot $syncRoot
    Assert-True ($restore.Action -eq 'Restore') 'Restore did not report its action.'
    Assert-True (Test-Path -LiteralPath $restore.PreRestoreBackupPath -PathType Leaf) 'Restore did not preserve the replaced local database.'
    $countScript = "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); print(db.execute('select count(*) from items').fetchone()[0]); db.close()"
    $count = & $python.Source @pythonPrefix -c $countScript $database
    Assert-True (($count | Select-Object -Last 1).Trim() -eq '1') 'Restore did not recover the exported transactionally consistent state.'

    [System.IO.File]::AppendAllText($export.SnapshotPath, 'tamper')
    $tamperRejected = $false
    try {
        & $tool -Action Restore -ProjectName 'fixture-project' -DatabasePath $database -LocalDataRoot $localRoot -SyncRoot $syncRoot -SnapshotPath $export.SnapshotPath | Out-Null
    }
    catch {
        $tamperRejected = $_.Exception.Message -like '*checksum*'
    }
    Assert-True $tamperRejected 'Restore accepted a snapshot with a mismatched checksum.'

    Remove-Item -LiteralPath $orphan -Force
    $retentionDirectory = Join-Path $root 'Retention Fixture'
    $retentionScript = @'
import importlib.util
import json
from pathlib import Path
import sys

module_path = Path(sys.argv[1])
directory = Path(sys.argv[2])
source_database = Path(sys.argv[3])
spec = importlib.util.spec_from_file_location("sqlite_project_data", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
directory.mkdir(parents=True, exist_ok=True)
stamps = [
    "20260729T120000Z", "20260728T120000Z", "20260727T120000Z",
    "20260720T120000Z", "20260713T120000Z", "20260706T120000Z",
    "20260629T120000Z", "20260531T120000Z", "20260430T120000Z",
]
for stamp in stamps:
    snapshot = directory / f"{stamp}-fixture.sqlite3"
    module.sqlite_backup(source_database, snapshot)
    checksum = module.sha256(snapshot)
    snapshot.with_suffix(snapshot.suffix + ".sha256").write_text(checksum + "\n", encoding="utf-8")
    created = (
        f"{stamp[0:4]}-{stamp[4:6]}-{stamp[6:8]}T"
        f"{stamp[9:11]}:{stamp[11:13]}:{stamp[13:15]}+00:00"
    )
    snapshot.with_suffix(snapshot.suffix + ".json").write_text(
        json.dumps({"createdUtc": created}) + "\n",
        encoding="utf-8",
    )
inventory = module.prune_snapshots(directory, daily=3, weekly=4, monthly=3, apply=False)
before_apply = [path.name for path in module.list_snapshots(directory)]
restore_destinations = []
original_backup = module.sqlite_backup
def capture_backup(source, destination):
    restore_destinations.append(destination)
    return original_backup(source, destination)
module.sqlite_backup = capture_backup
applied = module.prune_snapshots(directory, daily=3, weekly=4, monthly=3, apply=True)
print(json.dumps({
    "beforeApply": before_apply,
    "inventory": inventory,
    "applied": applied,
    "restoreOutsideSync": bool(restore_destinations) and directory not in restore_destinations[-1].parents,
    "retained": [path.name for path in module.list_snapshots(directory)],
}))
'@
    $retainedJson = $retentionScript | & $python.Source @pythonPrefix - $helper $retentionDirectory $database
    if ($LASTEXITCODE -ne 0) { throw 'Tiered retention fixture failed.' }
    $retentionResult = $retainedJson | ConvertFrom-Json
    Assert-True (@($retentionResult.beforeApply).Count -eq 9) 'Retention dry-run deleted snapshots before the apply gate.'
    Assert-True ($retentionResult.inventory.Applied -eq $false) 'Retention dry-run reported that deletion was applied.'
    Assert-True (@($retentionResult.inventory.Delete).Count -eq 1) 'Retention dry-run did not inventory the one expired point.'
    Assert-True ($retentionResult.applied.RestoreVerified -eq $true) 'Retention deletion lacked disposable restore proof for the newest point.'
    Assert-True ($retentionResult.restoreOutsideSync -eq $true) 'Disposable restore proof was written inside the synchronized snapshot directory.'
    $retained = @($retentionResult.retained | ForEach-Object { [string]$_ })
    Assert-True ($retained.Count -eq 8) "Tiered retention kept $($retained.Count) points; expected 8 unique 3 daily, 4 weekly, and 3 monthly points."
    Assert-True ($retained -contains '20260729T120000Z-fixture.sqlite3') 'Tiered retention dropped the newest daily point.'
    Assert-True ($retained -contains '20260629T120000Z-fixture.sqlite3') 'Tiered retention dropped the June monthly point.'
    Assert-True ($retained -contains '20260531T120000Z-fixture.sqlite3') 'Tiered retention dropped the May monthly point.'
    Assert-True ($retained -notcontains '20260430T120000Z-fixture.sqlite3') 'Tiered retention kept a monthly point beyond the configured limit.'

    $zeroRetentionDirectory = Join-Path $root 'Zero Retention Fixture'
    $zeroRetentionScript = @'
import importlib.util
import json
from pathlib import Path
import sys
spec = importlib.util.spec_from_file_location("sqlite_project_data", Path(sys.argv[1]))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
directory = Path(sys.argv[2])
source_database = Path(sys.argv[3])
directory.mkdir(parents=True, exist_ok=True)
fixtures = [
    ("20260729T120000Z-ffffffff.sqlite3", "2026-07-29T12:00:00.100000+00:00"),
    ("20260729T120000Z-00000000.sqlite3", "2026-07-29T12:00:00.900000+00:00"),
]
for name, created in fixtures:
    snapshot = directory / name
    module.sqlite_backup(source_database, snapshot)
    checksum = module.sha256(snapshot)
    snapshot.with_suffix(snapshot.suffix + ".sha256").write_text(checksum + "\n", encoding="utf-8")
    snapshot.with_suffix(snapshot.suffix + ".json").write_text(
        json.dumps({"createdUtc": created}) + "\n",
        encoding="utf-8",
    )
result = module.prune_snapshots(directory, daily=0, weekly=0, monthly=0, apply=True)
print(json.dumps({"result": result, "retained": [p.name for p in module.list_snapshots(directory)]}))
'@
    $zeroJson = $zeroRetentionScript | & $python.Source @pythonPrefix - $helper $zeroRetentionDirectory $database
    if ($LASTEXITCODE -ne 0) { throw 'Zero-tier retention fixture failed.' }
    $zeroResult = $zeroJson | ConvertFrom-Json
    Assert-True (@($zeroResult.retained).Count -eq 1) 'Zero-tier retention did not preserve the newest verified snapshot.'
    Assert-True ([string]$zeroResult.retained[0] -eq '20260729T120000Z-00000000.sqlite3') 'Zero-tier retention selected a UUID-lexicographic snapshot instead of the exact newest metadata timestamp.'
    Assert-True ($zeroResult.result.RestoreVerified -eq $true) 'Zero-tier retention deletion lacked restore proof.'

    $status = & $tool -Action Status -ProjectName 'fixture-project' -DatabasePath $database -LocalDataRoot $localRoot -SyncRoot $syncRoot
    Assert-True ($status.LocalDatabaseExists -eq $true) 'Status did not report the local database.'

    $outsideSnapshot = Join-Path $root 'outside.sqlite3'
    [System.IO.File]::WriteAllText($outsideSnapshot, 'outside')
    $outsideRejected = $false
    try {
        & $tool -Action Restore -ProjectName 'fixture-project' -DatabasePath $database -LocalDataRoot $localRoot -SyncRoot $syncRoot -SnapshotPath $outsideSnapshot | Out-Null
    }
    catch {
        $outsideRejected = $_.Exception.Message -match 'outside (the project sync directory|its declared root)'
    }
    Assert-True $outsideRejected 'Restore accepted a snapshot outside the project sync directory.'

    $reservedRejected = $false
    try {
        & $tool -Action Status -ProjectName 'CON' -DatabasePath $database -LocalDataRoot $localRoot -SyncRoot $syncRoot | Out-Null
    }
    catch {
        $reservedRejected = $_.Exception.Message -like '*unsafe project name*'
    }
    Assert-True $reservedRejected 'Windows reserved project name was accepted.'

    $outsideLocal = Join-Path $root 'Outside Local'
    $outsideDatabase = Join-Path $outsideLocal 'outside.sqlite3'
    New-Item -ItemType Directory -Path $outsideLocal -Force | Out-Null
    Copy-Item -LiteralPath $database -Destination $outsideDatabase
    $localAlias = Join-Path $localRoot 'runtime-alias'
    New-Item -ItemType Junction -Path $localAlias -Target $outsideLocal | Out-Null
    $localJunctionRejected = $false
    try {
        & $tool -Action Export -ProjectName 'fixture-project' `
            -DatabasePath (Join-Path $localAlias 'outside.sqlite3') `
            -LocalDataRoot $localRoot `
            -SyncRoot $syncRoot | Out-Null
    }
    catch {
        $localJunctionRejected = $_.Exception.Message -match 'reparse'
    }
    Assert-True $localJunctionRejected 'Export followed a database path through a local-data junction.'

    $syncExternal = Join-Path $root 'Outside Sync'
    $syncAlias = Join-Path $root 'Sync Alias'
    New-Item -ItemType Directory -Path $syncExternal -Force | Out-Null
    New-Item -ItemType Junction -Path $syncAlias -Target $syncExternal | Out-Null
    $syncJunctionRejected = $false
    try {
        & $tool -Action Export -ProjectName 'fixture-project' `
            -DatabasePath $database `
            -LocalDataRoot $localRoot `
            -SyncRoot $syncAlias | Out-Null
    }
    catch {
        $syncJunctionRejected = $_.Exception.Message -match 'reparse'
    }
    Assert-True $syncJunctionRejected 'Export wrote through a reparse-point project sync root.'

    $projectDirectoryExternal = Join-Path $root 'Outside Project Directory'
    New-Item -ItemType Directory -Path $projectDirectoryExternal -Force | Out-Null
    $projectDirectoryAlias = Join-Path $syncRoot 'linked-project'
    New-Item -ItemType Junction -Path $projectDirectoryAlias -Target $projectDirectoryExternal | Out-Null
    $projectDirectoryJunctionRejected = $false
    try {
        & $tool -Action Export -ProjectName 'linked-project' `
            -DatabasePath $database `
            -LocalDataRoot $localRoot `
            -SyncRoot $syncRoot | Out-Null
    }
    catch {
        $projectDirectoryJunctionRejected = $_.Exception.Message -match 'reparse'
    }
    Assert-True $projectDirectoryJunctionRejected 'Export followed a reparse-point project destination below the declared sync root.'

    $snapshotExternal = Join-Path $root 'Outside Snapshot'
    New-Item -ItemType Directory -Path $snapshotExternal -Force | Out-Null
    $snapshotAlias = Join-Path $snapshotDirectory 'snapshot-alias'
    New-Item -ItemType Junction -Path $snapshotAlias -Target $snapshotExternal | Out-Null
    Copy-Item -LiteralPath $export.SnapshotPath -Destination (Join-Path $snapshotExternal 'forged.sqlite3')
    Copy-Item -LiteralPath $export.ChecksumPath -Destination (Join-Path $snapshotExternal 'forged.sqlite3.sha256')
    $snapshotJunctionRejected = $false
    try {
        & $tool -Action Restore -ProjectName 'fixture-project' `
            -DatabasePath $database `
            -LocalDataRoot $localRoot `
            -SyncRoot $syncRoot `
            -SnapshotPath (Join-Path $snapshotAlias 'forged.sqlite3') | Out-Null
    }
    catch {
        $snapshotJunctionRejected = $_.Exception.Message -match 'reparse'
    }
    Assert-True $snapshotJunctionRejected 'Restore followed a snapshot path through a junction.'

    $localRootAlias = Join-Path $root 'Local Root Alias'
    New-Item -ItemType Junction -Path $localRootAlias -Target $localRoot | Out-Null
    $declaredRootJunctionRejected = $false
    try {
        & $tool -Action Status -ProjectName 'fixture-project' `
            -DatabasePath (Join-Path $localRootAlias 'runtime\app.sqlite3') `
            -LocalDataRoot $localRootAlias `
            -SyncRoot $syncRoot | Out-Null
    }
    catch {
        $declaredRootJunctionRejected = $_.Exception.Message -match 'reparse'
    }
    Assert-True $declaredRootJunctionRejected 'A reparse-point declared local-data root was accepted.'

    [pscustomobject]@{
        Result = 'PASS'
        AtomicExport = $true
        TransactionalBackup = $true
        RestoreBackup = $true
        ChecksumEnforced = $true
        PathsWithSpaces = $true
        IncompleteUploadIgnored = $true
        TieredRetention = '3 daily, 4 weekly, 3 monthly'
        OutsideRestoreRejected = $true
        ReservedNameRejected = $true
        LocalJunctionRejected = $true
        SyncJunctionRejected = $true
        ProjectDirectoryJunctionRejected = $true
        SnapshotJunctionRejected = $true
        DeclaredRootJunctionRejected = $true
    }
}
finally {
    if (Test-Path -LiteralPath $root) {
        $resolved = [System.IO.Path]::GetFullPath($root)
        if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
