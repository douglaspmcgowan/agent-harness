[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Export', 'Restore', 'Status', 'Prune')]
    [string]$Action,

    [Parameter(Mandatory)]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [string]$DatabasePath,

    [string]$LocalDataRoot = $env:PROJECT_DATA_ROOT,

    [string]$SyncRoot = $env:PROJECT_DATA_SYNC_ROOT,

    [string]$SnapshotPath,

    [ValidateRange(0, [int]::MaxValue)]
    [int]$Daily = 3,

    [ValidateRange(0, [int]::MaxValue)]
    [int]$Weekly = 4,

    [ValidateRange(0, [int]::MaxValue)]
    [int]$Monthly = 3,

    [switch]$ApplyRetentionPrune
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SyncRoot)) {
    throw 'PROJECT_DATA_SYNC_ROOT is unset. Point it to the Google Drive Project Data folder.'
}
if ([string]::IsNullOrWhiteSpace($LocalDataRoot)) {
    throw 'PROJECT_DATA_ROOT is unset. Point it to the declared local project-data folder.'
}
if ($ApplyRetentionPrune -and $Action -ne 'Prune') {
    throw 'ApplyRetentionPrune is valid only with Action Prune.'
}

function Assert-NoReparseAncestors {
    param([string]$Path, [string]$Label)

    $full = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($full)
    $current = $pathRoot
    foreach ($segment in @($full.Substring($pathRoot.Length).Trim('\') -split '\\' |
        Where-Object { $_ })) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse-point ancestor: $current"
        }
    }
}

function Assert-ContainedPath {
    param([string]$Path, [string]$Root, [string]$Label)

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not (
        [string]::Equals($pathFull.TrimEnd('\'), $rootFull, [StringComparison]::OrdinalIgnoreCase) -or
        $pathFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)
    )) {
        throw "$Label is outside its declared root."
    }
}

$localRootFull = [System.IO.Path]::GetFullPath($LocalDataRoot)
$syncRootFull = [System.IO.Path]::GetFullPath($SyncRoot)
$databaseFull = [System.IO.Path]::GetFullPath($DatabasePath)
Assert-NoReparseAncestors -Path $localRootFull -Label 'Local project-data root'
Assert-NoReparseAncestors -Path $syncRootFull -Label 'Project-data sync root'
Assert-NoReparseAncestors -Path $databaseFull -Label 'SQLite database path'
Assert-ContainedPath -Path $databaseFull -Root $localRootFull -Label 'SQLite database path'
if ($SnapshotPath) {
    $snapshotFull = [System.IO.Path]::GetFullPath($SnapshotPath)
    Assert-NoReparseAncestors -Path $snapshotFull -Label 'SQLite snapshot path'
    Assert-ContainedPath -Path $snapshotFull -Root $syncRootFull -Label 'SQLite snapshot path'
}

$helper = Join-Path $PSScriptRoot 'sqlite_project_data.py'
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
    throw "SQLite project-data helper is missing: $helper"
}

function Resolve-Python {
    $candidates = [Collections.Generic.List[object]]::new()
    foreach ($commandName in @('python.exe', 'py.exe')) {
        Get-Command $commandName -All -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($_.Source) {
                    $prefix = if ($_.Name -ieq 'py.exe') { @('-3') } else { @() }
                    $candidates.Add([pscustomobject]@{ Source = $_.Source; Prefix = [string[]]$prefix })
                }
            }
    }
    if ($env:USERPROFILE) {
        $programsPython = Join-Path $env:USERPROFILE 'AppData\Local\Programs\Python'
        Get-ChildItem -LiteralPath $programsPython -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'python.exe' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            ForEach-Object {
                $candidates.Add([pscustomobject]@{ Source = $_; Prefix = [string[]]@() })
            }
    }

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($candidate in $candidates) {
        if (-not $seen.Add([string]$candidate.Source)) {
            continue
        }
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $candidate.Source @($candidate.Prefix) -c 'import sqlite3,sys; sys.exit(0)' 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                return $candidate
            }
        }
        catch {}
        finally {
            $ErrorActionPreference = $previousPreference
        }
    }
    throw 'A runnable Python 3 installation with sqlite3 support is required for SQLite project-data synchronization.'
}

$python = Resolve-Python
$arguments = [System.Collections.Generic.List[string]]::new()
foreach ($prefixArgument in @($python.Prefix)) { $arguments.Add($prefixArgument) }
$arguments.Add($helper)
$arguments.Add('--action')
$arguments.Add($Action)
$arguments.Add('--project')
$arguments.Add($ProjectName)
$arguments.Add('--database')
$arguments.Add($databaseFull)
$arguments.Add('--local-root')
$arguments.Add($localRootFull)
$arguments.Add('--sync-root')
$arguments.Add($syncRootFull)
$arguments.Add('--daily')
$arguments.Add([string]$Daily)
$arguments.Add('--weekly')
$arguments.Add([string]$Weekly)
$arguments.Add('--monthly')
$arguments.Add([string]$Monthly)
if ($SnapshotPath) {
    $arguments.Add('--snapshot')
    $arguments.Add($snapshotFull)
}
if ($ApplyRetentionPrune) {
    $arguments.Add('--apply-retention-prune')
}

$previousPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    [string[]]$nativeArguments = $arguments.ToArray()
    $output = @(& $python.Source @nativeArguments 2>&1)
}
finally {
    $ErrorActionPreference = $previousPreference
}
$exitCode = $LASTEXITCODE
$text = ($output | ForEach-Object { [string]$_ }) -join "`n"
if ($exitCode -ne 0) {
    throw $text.Trim()
}

try {
    $text | ConvertFrom-Json
}
catch {
    throw 'SQLite project-data helper returned invalid JSON.'
}
