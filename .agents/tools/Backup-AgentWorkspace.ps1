[CmdletBinding()]
param(
    [string]$ProjectsRoot = (Join-Path $env:USERPROFILE 'projects'),
    [string[]]$ProjectExcludes = @('general-claude'),
    [string]$ProjectDataRoot = (Join-Path $env:USERPROFILE 'Data\Projects'),
    [string[]]$ProjectDataExcludes = @(
        'agent-harness',
        'harness-adversarial-test',
        'harness-bootstrap-verification-20260726'
    ),
    [string]$BackupRoot = (Join-Path $env:USERPROFILE 'Documents\Agent Backups\Workspace'),
    [hashtable]$ProductConfig = @{
        claude = @(
            (Join-Path $env:USERPROFILE '.claude\CLAUDE.md'),
            (Join-Path $env:USERPROFILE '.claude\VERIFY.md'),
            (Join-Path $env:USERPROFILE '.claude\keybindings.json')
        )
        cursor = @(
            (Join-Path $env:USERPROFILE '.cursor\MCP-INVENTORY.md'),
            (Join-Path $env:USERPROFILE '.cursor\permissions.json'),
            (Join-Path $env:USERPROFILE '.cursor\settings.json'),
            (Join-Path $env:USERPROFILE '.cursor\rules')
        )
    },
    [string[]]$SQLiteSources = @(
        (Join-Path $env:USERPROFILE '.docket-local\docket.sqlite3')
    ),
    [string]$SnapshotName = (Get-Date -Format 'yyyyMMdd-HHmmss'),
    [switch]$SkipQuickAccess
)

$ErrorActionPreference = 'Stop'
$snapshotRoot = Join-Path (Join-Path $BackupRoot 'Snapshots') $SnapshotName
if (Test-Path -LiteralPath $snapshotRoot) {
    throw "Snapshot already exists: $snapshotRoot"
}

function Write-Utf8Json {
    param([object]$Value, [string]$Path, [int]$Depth = 8)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [System.IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Test-ForbiddenBackupPath {
    param([string]$RelativePath)
    $segments = $RelativePath -split '[\\/]'
    $leaf = $segments[-1]
    if ($segments -contains '.git') { return $true }
    if ($segments -contains 'Restricted') { return $true }
    if ($leaf -match '^(?i)\.env($|\.)|credential|credentials|token|password|passcode|recovery.?key|cookies?$') { return $true }
    if ($leaf -match '(?i)-(wal|shm)$') { return $true }
    return $false
}

function ConvertTo-ExtendedPath {
    param([string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith('\\')) {
        return '\\?\UNC\' + $fullPath.TrimStart('\')
    }
    return '\\?\' + $fullPath
}

function Copy-LongPathFile {
    param([string]$Source, [string]$Destination)
    $parent = Split-Path -Parent $Destination
    [System.IO.Directory]::CreateDirectory((ConvertTo-ExtendedPath $parent)) | Out-Null
    [System.IO.File]::Copy(
        (ConvertTo-ExtendedPath $Source),
        (ConvertTo-ExtendedPath $Destination),
        $false
    )
}

function Copy-ApprovedTree {
    param([string]$Source, [string]$Destination, [switch]$SkipSQLite)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { return }
    Get-ChildItem -LiteralPath $Source -File -Recurse -Force | ForEach-Object {
        $relative = $_.FullName.Substring($Source.Length).TrimStart('\')
        if (Test-ForbiddenBackupPath $relative) { return }
        if ($SkipSQLite -and $_.Extension -match '^(?i)\.(db|sqlite|sqlite3)$') { return }
        $target = Join-Path $Destination $relative
        Copy-LongPathFile -Source $_.FullName -Destination $target
    }
}

function New-SanitizedTipBundle {
    param(
        [string]$Repository,
        [string]$SafeRepository,
        [string]$BundlePath,
        [string]$ProjectName
    )

    $root = Join-Path $env:TEMP ("agent-tip-bundle-" + [Guid]::NewGuid().ToString('N'))
    $archive = Join-Path $root 'tip.zip'
    $tree = Join-Path $root 'tree'
    $report = Join-Path $root 'gitleaks-redacted.json'
    $omissionCount = 0
    try {
        New-Item -ItemType Directory -Path $tree -Force | Out-Null
        git -c "safe.directory=$SafeRepository" -C $Repository archive --format=zip --output=$archive HEAD
        if ($LASTEXITCODE -ne 0) { throw "Current-tree archive failed for $ProjectName." }
        Expand-Archive -LiteralPath $archive -DestinationPath $tree

        if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
            & gitleaks dir --no-banner --redact --exit-code 1 --report-format json --report-path $report $tree
            if ($LASTEXITCODE -ne 0) {
                if (-not (Test-Path -LiteralPath $report -PathType Leaf)) {
                    throw "Gitleaks blocked the current-tree recovery bundle for $ProjectName without a redacted report."
                }
                $findings = @(Get-Content -LiteralPath $report -Raw | ConvertFrom-Json)
                $flaggedFiles = @($findings | ForEach-Object { [string]$_.File } | Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                } | Sort-Object -Unique)
                if (-not $flaggedFiles.Count) {
                    throw "Gitleaks blocked the current-tree recovery bundle for $ProjectName without a removable file boundary."
                }
                foreach ($flagged in $flaggedFiles) {
                    $candidate = if ([System.IO.Path]::IsPathRooted($flagged)) {
                        [System.IO.Path]::GetFullPath($flagged)
                    }
                    else {
                        [System.IO.Path]::GetFullPath((Join-Path $tree $flagged))
                    }
                    $treePrefix = [System.IO.Path]::GetFullPath($tree).TrimEnd('\') + '\'
                    if (-not $candidate.StartsWith($treePrefix, [StringComparison]::OrdinalIgnoreCase)) {
                        throw "Gitleaks returned an unsafe recovery omission path for $ProjectName."
                    }
                    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                        Remove-Item -LiteralPath $candidate -Force
                        $omissionCount += 1
                    }
                }
                [System.IO.File]::WriteAllText(
                    (Join-Path $tree 'RECOVERY-OMISSIONS.md'),
                    "# Recovery omissions`n`n$omissionCount tracked file(s) were excluded from this offline current-tree bundle by the Gitleaks gate. Restore published tracked material from the recorded GitHub remote after authentication.`n",
                    [System.Text.UTF8Encoding]::new($false)
                )
                & gitleaks dir --no-banner --redact --exit-code 1 $tree
                if ($LASTEXITCODE -ne 0) {
                    throw "Gitleaks blocked the reduced current-tree recovery bundle for $ProjectName."
                }
            }
        }

        git -C $tree init | Out-Null
        git -C $tree config user.name 'Agent Backups'
        git -C $tree config user.email 'agent-backups@example.invalid'
        git -C $tree add -A
        git -c core.hooksPath= -C $tree commit -m 'Portable recovery snapshot' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Current-tree recovery commit failed for $ProjectName." }
        git -C $tree bundle create $BundlePath --all
        if ($LASTEXITCODE -ne 0) { throw "Current-tree recovery bundle failed for $ProjectName." }
        return $omissionCount
    }
    finally {
        if (Test-Path -LiteralPath $root) {
            $resolved = (Resolve-Path -LiteralPath $root).Path
            if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolved -Recurse -Force
            }
        }
    }
}

function Test-OfflineBundleClone {
    param(
        [string]$BundlePath,
        [string]$ProjectName
    )

    $root = Join-Path $env:TEMP ("agent-bundle-clone-" + [Guid]::NewGuid().ToString('N'))
    try {
        git clone $BundlePath (Join-Path $root 'clone') | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    finally {
        if (Test-Path -LiteralPath $root) {
            $resolved = (Resolve-Path -LiteralPath $root).Path
            if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolved -Recurse -Force
            }
        }
    }
}

function Get-NormalizedQuickAccessPath {
    param([string]$Path)
    $profile = [Environment]::GetFolderPath('UserProfile').TrimEnd('\')
    $driveRoot = Join-Path $profile 'My Drive'
    if ($Path.StartsWith((Join-Path $profile 'OneDrive\Documents\General Claude'), [StringComparison]::OrdinalIgnoreCase)) {
        return '%USERPROFILE%\projects'
    }
    if ($Path.StartsWith((Join-Path $profile 'OneDrive\Documents\Sound Recordings'), [StringComparison]::OrdinalIgnoreCase)) {
        return '%USERPROFILE%\Documents\Sound Recordings'
    }
    foreach ($knownFolder in @('Desktop', 'Documents', 'Downloads', 'Pictures', 'Music', 'Videos')) {
        $retired = Join-Path $profile ("OneDrive\" + $knownFolder)
        if ($Path.StartsWith($retired, [StringComparison]::OrdinalIgnoreCase)) {
            return '%USERPROFILE%\' + $knownFolder + $Path.Substring($retired.Length)
        }
    }
    if ($Path.StartsWith('G:\My Drive', [StringComparison]::OrdinalIgnoreCase)) {
        return '%GOOGLE_DRIVE_ROOT%' + $Path.Substring('G:\My Drive'.Length)
    }
    if ($Path.StartsWith($driveRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return '%GOOGLE_DRIVE_ROOT%' + $Path.Substring($driveRoot.Length)
    }
    if ($Path.StartsWith($profile, [StringComparison]::OrdinalIgnoreCase)) {
        return '%USERPROFILE%' + $Path.Substring($profile.Length)
    }
    return $Path
}

New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
$projectRecords = @()

Get-ChildItem -LiteralPath $ProjectsRoot -Directory | Where-Object {
    $_.Name -notlike '*incomplete-*' -and
    $_.Name -notin $ProjectExcludes -and
    (Test-Path -LiteralPath (Join-Path $_.FullName '.git'))
} | Sort-Object Name | ForEach-Object {
    $projectPath = $_.FullName
    $safePath = $projectPath.Replace('\', '/')
    $remotes = @(git -c "safe.directory=$safePath" -C $projectPath remote)
    $remote = if ($remotes -contains 'origin') {
        [string](git -c "safe.directory=$safePath" -C $projectPath remote get-url origin)
    } else { '' }
    $branch = [string](git -c "safe.directory=$safePath" -C $projectPath branch --show-current)
    if ($null -eq $branch) { $branch = '' } else { $branch = $branch.Trim() }
    if (-not $branch) { $branch = 'master' }
    $commit = [string](git -c "safe.directory=$safePath" -C $projectPath rev-list -1 --all)
    if ($null -eq $commit) { $commit = '' } else { $commit = $commit.Trim() }
    $status = @(git -c "safe.directory=$safePath" -C $projectPath status --porcelain)
    $handoffRoot = Join-Path $snapshotRoot ("Handoffs\" + $_.Name)
    New-Item -ItemType Directory -Path $handoffRoot -Force | Out-Null
    $recoveryMode = if ($remote -and $commit) { 'remote' } elseif ($commit) { 'bundle' } else { 'files' }

    $bundleIncluded = $false
    $offlineBundleMode = 'none'
    $offlineOmittedFiles = 0
    $offlineBundleCloneVerified = $false
    if ($commit) {
        $historyClean = $true
        if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
            & gitleaks git --no-banner --redact --exit-code 1 $projectPath
            if ($LASTEXITCODE -ne 0) {
                $historyClean = $false
            }
        }
        $bundlePath = Join-Path $handoffRoot 'Repository.bundle'
        if ($historyClean) {
            git -c "safe.directory=$safePath" -C $projectPath bundle create $bundlePath --all
            if ($LASTEXITCODE -ne 0) { throw "Repository bundle failed for $($_.Name)." }
            $offlineBundleCloneVerified = Test-OfflineBundleClone -BundlePath $bundlePath -ProjectName $_.Name
            if ($offlineBundleCloneVerified) {
                $offlineBundleMode = 'history'
            }
            else {
                Remove-Item -LiteralPath $bundlePath -Force
                $offlineOmittedFiles = New-SanitizedTipBundle `
                    -Repository $projectPath `
                    -SafeRepository $safePath `
                    -BundlePath $bundlePath `
                    -ProjectName $_.Name
                $offlineBundleMode = 'sanitized-tip'
            }
        }
        else {
            $offlineOmittedFiles = New-SanitizedTipBundle `
                -Repository $projectPath `
                -SafeRepository $safePath `
                -BundlePath $bundlePath `
                -ProjectName $_.Name
            $offlineBundleMode = 'sanitized-tip'
        }
        if (-not $offlineBundleCloneVerified) {
            $offlineBundleCloneVerified = Test-OfflineBundleClone -BundlePath $bundlePath -ProjectName $_.Name
        }
        if (-not $offlineBundleCloneVerified) {
            throw "Offline recovery bundle failed a clean clone for $($_.Name)."
        }
        $bundleIncluded = $true
    }

    $uncommittedRoot = Join-Path $env:TEMP ("agent-uncommitted-" + [Guid]::NewGuid().ToString('N'))
    $snapshotIncluded = $false
    try {
        if ($status.Count) {
            New-Item -ItemType Directory -Path $uncommittedRoot -Force | Out-Null
            $workingPatch = if ($commit) {
                @(git -c "safe.directory=$safePath" -C $projectPath diff --binary) -join [Environment]::NewLine
            } else { '' }
            $stagedPatch = if ($commit) {
                @(git -c "safe.directory=$safePath" -C $projectPath diff --binary --cached) -join [Environment]::NewLine
            } else { '' }
            if ($workingPatch) {
                [System.IO.File]::WriteAllText((Join-Path $uncommittedRoot 'working.patch'), $workingPatch + [Environment]::NewLine)
            }
            if ($stagedPatch) {
                [System.IO.File]::WriteAllText((Join-Path $uncommittedRoot 'staged.patch'), $stagedPatch + [Environment]::NewLine)
            }
            $untracked = @(git -c "safe.directory=$safePath" -C $projectPath ls-files --others --exclude-standard)
            foreach ($relative in $untracked) {
                if (Test-ForbiddenBackupPath $relative) { continue }
                $source = Join-Path $projectPath $relative
                if (Test-Path -LiteralPath $source -PathType Leaf) {
                    $target = Join-Path (Join-Path $uncommittedRoot 'untracked') $relative
                    Copy-LongPathFile -Source $source -Destination $target
                }
            }

            if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
                & gitleaks dir --no-banner --redact --exit-code 1 $uncommittedRoot
                if ($LASTEXITCODE -ne 0) {
                    throw "Gitleaks blocked the uncommitted snapshot for $($_.Name)."
                }
            }
            Copy-ApprovedTree -Source $uncommittedRoot -Destination (Join-Path $handoffRoot 'Uncommitted')
            $snapshotIncluded = $true
        }
    }
    finally {
        if (Test-Path -LiteralPath $uncommittedRoot) {
            $resolvedTemp = (Resolve-Path -LiteralPath $uncommittedRoot).Path
            if ($resolvedTemp.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
            }
        }
    }

    $record = [ordered]@{
        name = $_.Name
        sourcePath = $projectPath
        remote = [string]$remote
        branch = $branch
        commit = $commit
        recoveryMode = $recoveryMode
        offlineBundle = $bundleIncluded
        offlineBundleMode = $offlineBundleMode
        offlineOmittedFiles = $offlineOmittedFiles
        offlineBundleCloneVerified = $offlineBundleCloneVerified
        dirtyEntries = $status.Count
        uncommittedSnapshot = $snapshotIncluded
    }
    $projectRecords += $record
    $handoff = @"
# $($_.Name) recovery handoff

Generated: $((Get-Date).ToUniversalTime().ToString('o'))

- Remote authority: `$remote`
- Branch: `$branch`
- Commit: `$commit`
- Recovery mode: `$recoveryMode`
- Offline bundle mode: `$offlineBundleMode`
- Offline omitted files: `$offlineOmittedFiles`
- Dirty entries: $($status.Count)
- Uncommitted snapshot included: $snapshotIncluded

Restore with `Restore-AgentWorkspace.ps1`; then read `AGENTS.md`, `TASK.md`, `STATUS.md`, and the recent entries in `LOG.md` in this repository.
"@
    [System.IO.File]::WriteAllText(
        (Join-Path $handoffRoot 'HANDOFF.md'),
        $handoff + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$recoveryManifest = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    machine = $env:COMPUTERNAME
    projectsRoot = $ProjectsRoot
    projects = $projectRecords
}
Write-Utf8Json -Value $recoveryManifest -Path (Join-Path $snapshotRoot 'Recovery\project-recovery.json')

if (Test-Path -LiteralPath $ProjectDataRoot -PathType Container) {
    Get-ChildItem -LiteralPath $ProjectDataRoot -Directory | Where-Object {
        $_.Name -notin $ProjectDataExcludes
    } | ForEach-Object {
        Copy-ApprovedTree `
            -Source $_.FullName `
            -Destination (Join-Path $snapshotRoot ("Application Data\Projects\" + $_.Name)) `
            -SkipSQLite
    }
}

$sqlite = Get-Command sqlite3.exe -ErrorAction SilentlyContinue
if (-not $sqlite) { $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue }
foreach ($database in $SQLiteSources) {
    if (-not (Test-Path -LiteralPath $database -PathType Leaf)) { continue }
    if (-not $sqlite) { throw "SQLite CLI is required to back up $database." }
    $name = [System.IO.Path]::GetFileName($database)
    $target = Join-Path $snapshotRoot ("Application Data\SQLite\" + $name)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    & $sqlite.Source $database ".backup '$($target.Replace("'", "''"))'"
    if ($LASTEXITCODE -ne 0) { throw "SQLite backup failed for $database." }
}

foreach ($product in $ProductConfig.Keys) {
    foreach ($source in @($ProductConfig[$product])) {
        if (-not (Test-Path -LiteralPath $source)) { continue }
        $targetRoot = Join-Path $snapshotRoot ("Product Configuration\" + $product)
        if (Test-Path -LiteralPath $source -PathType Container) {
            Copy-ApprovedTree -Source $source -Destination (Join-Path $targetRoot ([System.IO.Path]::GetFileName($source)))
        }
        else {
            New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination (Join-Path $targetRoot ([System.IO.Path]::GetFileName($source)))
        }
    }
}

if (-not $SkipQuickAccess) {
    $shell = New-Object -ComObject Shell.Application
    $quickAccess = $shell.Namespace('shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}')
    $pins = @($quickAccess.Items() | Where-Object {
        $_.IsFolder -and $_.ExtendedProperty('System.Home.IsPinned')
    } | ForEach-Object {
        Get-NormalizedQuickAccessPath -Path $_.Path
    } | Sort-Object -Unique)
    Write-Utf8Json -Value ([ordered]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        pinnedFolders = $pins
    }) -Path (Join-Path $snapshotRoot 'Recovery\quick-access.json')
}

if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
    & gitleaks dir --no-banner --redact --exit-code 1 $snapshotRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Gitleaks blocked the completed Agent Backups snapshot.'
    }
}

Write-Utf8Json -Value ([ordered]@{
    schemaVersion = 1
    snapshotName = $SnapshotName
    snapshotRoot = $snapshotRoot
    completedAt = (Get-Date).ToUniversalTime().ToString('o')
}) -Path (Join-Path $BackupRoot 'Recovery\latest.json')

[pscustomobject]@{
    SnapshotRoot = $snapshotRoot
    Projects = $projectRecords.Count
    CompletedAt = (Get-Date).ToUniversalTime().ToString('o')
}
