[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupRoot,
    [string]$UserRoot = $env:USERPROFILE,
    [switch]$SkipQuickAccess
)

$ErrorActionPreference = 'Stop'

function ConvertTo-ExtendedPath {
    param([string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith('\\')) {
        return '\\?\UNC\' + $fullPath.TrimStart('\')
    }
    return '\\?\' + $fullPath
}

function Copy-Tree {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { return }
    Get-ChildItem -LiteralPath $Source -File -Recurse -Force | ForEach-Object {
        $relative = $_.FullName.Substring($Source.Length).TrimStart('\')
        $target = Join-Path $Destination $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        if (Test-Path -LiteralPath $target) {
            throw "Restore target already exists: $target"
        }
        [System.IO.Directory]::CreateDirectory((ConvertTo-ExtendedPath (Split-Path -Parent $target))) | Out-Null
        [System.IO.File]::Copy(
            (ConvertTo-ExtendedPath $_.FullName),
            (ConvertTo-ExtendedPath $target),
            $false
        )
    }
}

function Expand-RecoveryPath {
    param([string]$Path)
    $driveRoot = Join-Path $UserRoot 'My Drive'
    return $Path.Replace('%USERPROFILE%', $UserRoot).Replace('%GOOGLE_DRIVE_ROOT%', $driveRoot)
}

function Resolve-PortableSnapshotRoot {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$SnapshotName
    )

    if ([string]::IsNullOrWhiteSpace($SnapshotName) -or
        $SnapshotName -ne [System.IO.Path]::GetFileName($SnapshotName) -or
        $SnapshotName -in @('.', '..')) {
        throw "Invalid snapshot name in latest recovery pointer: $SnapshotName"
    }
    $snapshotsRoot = [System.IO.Path]::GetFullPath((Join-Path $Root 'Snapshots')).TrimEnd('\') + '\'
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $snapshotsRoot $SnapshotName))
    if (-not $candidate.StartsWith($snapshotsRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Snapshot pointer resolves outside the backup root: $SnapshotName"
    }
    return $candidate
}

$snapshotRoot = $BackupRoot
$directManifest = Join-Path $snapshotRoot 'Recovery\project-recovery.json'
if (-not (Test-Path -LiteralPath $directManifest)) {
    $latestPath = Join-Path $BackupRoot 'Recovery\latest.json'
    if (-not (Test-Path -LiteralPath $latestPath)) {
        throw 'The backup root contains no recovery manifest.'
    }
    $latest = Get-Content -LiteralPath $latestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $snapshotName = if ($latest.PSObject.Properties.Name -contains 'snapshotName') {
        [string]$latest.snapshotName
    }
    else {
        Split-Path -Leaf ([string]$latest.snapshotRoot)
    }
    $snapshotRoot = Resolve-PortableSnapshotRoot -Root $BackupRoot -SnapshotName $snapshotName
    $directManifest = Join-Path $snapshotRoot 'Recovery\project-recovery.json'
}
if (-not (Test-Path -LiteralPath $directManifest -PathType Leaf)) {
    throw "The selected snapshot contains no recovery manifest: $snapshotRoot"
}

$manifest = Get-Content -LiteralPath $directManifest -Raw -Encoding UTF8 | ConvertFrom-Json
$projectsRoot = Join-Path $UserRoot 'projects'
New-Item -ItemType Directory -Path $projectsRoot -Force | Out-Null

foreach ($project in @($manifest.projects)) {
    $target = Join-Path $projectsRoot ([string]$project.name)
    if (Test-Path -LiteralPath $target) {
        throw "Project restore target already exists: $target"
    }
    $recordedMode = if ($project.PSObject.Properties.Name -contains 'recoveryMode') {
        [string]$project.recoveryMode
    } elseif ([string]$project.remote) { 'remote' } else { 'bundle' }
    $bundle = Join-Path $snapshotRoot ("Handoffs\$($project.name)\Repository.bundle")
    $mode = if (Test-Path -LiteralPath $bundle -PathType Leaf) { 'bundle' } else { $recordedMode }

    if ($mode -eq 'remote') {
        git clone --branch ([string]$project.branch) --single-branch ([string]$project.remote) $target
        if ($LASTEXITCODE -ne 0) { throw "Clone failed for $($project.name)." }
    }
    elseif ($mode -eq 'bundle') {
        git clone $bundle $target
        if ($LASTEXITCODE -ne 0) { throw "Bundle restore failed for $($project.name)." }
        if (-not [string]::IsNullOrWhiteSpace([string]$project.remote)) {
            git -C $target remote rename origin capsule
            if ($LASTEXITCODE -ne 0) { throw "Capsule remote rename failed for $($project.name)." }
            git -C $target remote add origin ([string]$project.remote)
            if ($LASTEXITCODE -ne 0) { throw "Recorded remote restore failed for $($project.name)." }
        }
    }
    elseif ($mode -eq 'files') {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        git -C $target init | Out-Null
    }
    else {
        throw "Unknown recovery mode for $($project.name): $mode"
    }

    $safeTarget = $target.Replace('\', '/')
    $head = if ($mode -eq 'files') {
        ''
    } else {
        [string](git -c "safe.directory=$safeTarget" -C $target rev-parse --verify HEAD)
    }
    if ($null -eq $head) { $head = '' } else { $head = $head.Trim() }
    $offlineBundleMode = if ($project.PSObject.Properties.Name -contains 'offlineBundleMode') {
        [string]$project.offlineBundleMode
    } else { 'history' }
    if ([string]$project.commit -and
        $head -ne [string]$project.commit -and
        $offlineBundleMode -ne 'sanitized-tip') {
        git -c "safe.directory=$safeTarget" -C $target checkout ([string]$project.commit)
        if ($LASTEXITCODE -ne 0) { throw "Recorded commit could not be restored for $($project.name)." }
    }

    $uncommitted = Join-Path $snapshotRoot ("Handoffs\$($project.name)\Uncommitted")
    $stagedPatch = Join-Path $uncommitted 'staged.patch'
    $workingPatch = Join-Path $uncommitted 'working.patch'
    if (Test-Path -LiteralPath $stagedPatch) {
        git -c "safe.directory=$safeTarget" -C $target apply --binary $stagedPatch
        if ($LASTEXITCODE -ne 0) { throw "Staged patch restore failed for $($project.name)." }
        git -c "safe.directory=$safeTarget" -C $target add -A
    }
    if (Test-Path -LiteralPath $workingPatch) {
        git -c "safe.directory=$safeTarget" -C $target apply --binary $workingPatch
        if ($LASTEXITCODE -ne 0) { throw "Working patch restore failed for $($project.name)." }
    }
    Copy-Tree -Source (Join-Path $uncommitted 'untracked') -Destination $target
}

Copy-Tree `
    -Source (Join-Path $snapshotRoot 'Application Data\Projects') `
    -Destination (Join-Path $UserRoot 'Data\Projects')

$productRoot = Join-Path $snapshotRoot 'Product Configuration'
if (Test-Path -LiteralPath $productRoot) {
    Get-ChildItem -LiteralPath $productRoot -Directory | ForEach-Object {
        Copy-Tree -Source $_.FullName -Destination (Join-Path $UserRoot ('.' + $_.Name))
    }
}

if (-not $SkipQuickAccess -and [string]::Equals(
    [System.IO.Path]::GetFullPath($UserRoot),
    [System.IO.Path]::GetFullPath($env:USERPROFILE),
    [StringComparison]::OrdinalIgnoreCase
)) {
    $quickAccessPath = Join-Path $snapshotRoot 'Recovery\quick-access.json'
    if (Test-Path -LiteralPath $quickAccessPath) {
        $shell = New-Object -ComObject Shell.Application
        $quickAccess = $shell.Namespace('shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}')
        @($quickAccess.Items() | Where-Object {
            $_.IsFolder -and $_.ExtendedProperty('System.Home.IsPinned') -and
            ($_.Path.StartsWith((Join-Path $env:USERPROFILE 'OneDrive'), [StringComparison]::OrdinalIgnoreCase) -or
             $_.Path.StartsWith('G:\My Drive', [StringComparison]::OrdinalIgnoreCase))
        }) | ForEach-Object {
            $_.InvokeVerb('unpinfromhome')
        }

        $quickAccessManifest = Get-Content -LiteralPath $quickAccessPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($portablePath in @($quickAccessManifest.pinnedFolders)) {
            $path = Expand-RecoveryPath -Path ([string]$portablePath)
            if (Test-Path -LiteralPath $path -PathType Container) {
                $folder = $shell.Namespace($path)
                if ($folder) { $folder.Self.InvokeVerb('pintohome') }
            }
        }
    }
}

[pscustomobject]@{
    SnapshotRoot = $snapshotRoot
    ProjectsRestored = @($manifest.projects).Count
    UserRoot = $UserRoot
}
