[CmdletBinding()]
param(
    [string]$CapsuleRoot,
    [string]$UserRoot = $env:USERPROFILE,
    [string]$TrustedHarnessRepository = (Join-Path $env:USERPROFILE 'projects\agent-harness'),
    [string]$ObsidianVaultRoot,
    [string]$ObsidianRegistryPath = (Join-Path $env:APPDATA 'obsidian\obsidian.json'),
    [string]$GoogleDriveMyDriveRoot,
    [string[]]$GoogleDriveCandidates,
    [scriptblock]$ProjectDataEnvironmentReadOperation,
    [scriptblock]$ProjectDataEnvironmentWriteOperation,
    [switch]$SkipObsidianConfig,
    [switch]$SkipProjectDataEnvironment,
    [switch]$ProjectDataEnvironmentDryRun,
    [switch]$SkipPackageInstall,
    [switch]$SkipAccountLogin,
    [switch]$SkipQuickAccess
)

$ErrorActionPreference = 'Stop'
if (-not $CapsuleRoot) {
    $CapsuleRoot = Split-Path -Parent $PSScriptRoot
}
$CapsuleRoot = [System.IO.Path]::GetFullPath($CapsuleRoot)
$UserRoot = [System.IO.Path]::GetFullPath($UserRoot)
if (-not $GoogleDriveMyDriveRoot) {
    $capsuleParent = Split-Path -Parent $CapsuleRoot
    if ([string]::Equals(
        (Split-Path -Leaf $capsuleParent),
        'My Drive',
        [StringComparison]::OrdinalIgnoreCase
    )) {
        $GoogleDriveMyDriveRoot = $capsuleParent
    }
}

function Resolve-ContainedCapsulePath {
    param([string]$Root, [string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        (($RelativePath -split '[\\/]') -contains '..')) {
        throw "Capsule manifest path is unsafe: $RelativePath"
    }
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not $candidate.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Capsule manifest path resolves outside the Capsule: $RelativePath"
    }
    return $candidate
}

function Enter-TargetLock {
    param([string]$Target)

    $lockDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'AgentHarness-BootstrapLocks'
    New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
    $lockDirectoryItem = Get-Item -LiteralPath $lockDirectory -Force
    if (($lockDirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Bootstrap lock directory must not be a reparse point: $lockDirectory"
    }
    $normalized = [System.IO.Path]::GetFullPath($Target).TrimEnd('\').ToLowerInvariant()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = ([BitConverter]::ToString(
            $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($normalized))
        )).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
    $lockPath = Join-Path $lockDirectory ($hash + '.lock')
    if (Test-Path -LiteralPath $lockPath) {
        $lockItem = Get-Item -LiteralPath $lockPath -Force
        if (($lockItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Bootstrap lock must not be a reparse point: $lockPath"
        }
    }
    try {
        return [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    }
    catch {
        throw "Another Capsule bootstrap is active for $normalized"
    }
}

function Assert-NoReparseAncestors {
    param([string]$Path, [string]$Label)

    $full = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($full)
    $current = $pathRoot
    $relative = $full.Substring($pathRoot.Length).Trim('\')
    foreach ($candidate in @($pathRoot) + @($relative -split '\\' | Where-Object { $_ })) {
        if (-not [string]::Equals($candidate, $pathRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $current = Join-Path $current $candidate
        }
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse-point ancestor: $current"
        }
    }
}

Assert-NoReparseAncestors -Path $CapsuleRoot -Label 'Capsule source path'
Assert-NoReparseAncestors -Path $UserRoot -Label 'Shared harness target path'
& (Join-Path $CapsuleRoot 'tools\Verify-Capsule.ps1') `
    -CapsuleRoot $CapsuleRoot `
    -TrustedHarnessRepository $TrustedHarnessRepository | Out-Null
$agentsTarget = Join-Path $UserRoot '.agents'
$bootstrapLock = Enter-TargetLock -Target $agentsTarget
try {

if (-not $SkipPackageInstall) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'Windows Package Manager is required. Install App Installer from Microsoft Store, then rerun.'
    }
    $software = Get-Content -LiteralPath (Join-Path $CapsuleRoot 'manifests\software.json') -Raw -Encoding UTF8 |
        ConvertFrom-Json
    foreach ($package in @($software.packages | Where-Object { $_.wingetId })) {
        & $winget.Source install `
            --id ([string]$package.wingetId) `
            --exact `
            --accept-package-agreements `
            --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "Package installation failed: $($package.name)"
        }
    }
}

if (-not $SkipAccountLogin) {
    Write-Host ''
    Write-Host 'Complete these account sign-ins when each application first opens:'
    Write-Host '1. Google Drive for the shared Capsule and selected large project data.'
    Write-Host '2. Bitwarden for the Agents organization and this computer machine token.'
    Write-Host '3. GitHub CLI for repository discovery, clone, pull, and push.'
    Write-Host '4. Claude, Codex, Cursor, and Obsidian.'
    Write-Host ''
}

$projectDataResult = $null
if (-not $SkipProjectDataEnvironment) {
    $projectDataArguments = @{
        UserRoot = $UserRoot
        Apply = -not $ProjectDataEnvironmentDryRun
    }
    if ($GoogleDriveMyDriveRoot) {
        $projectDataArguments.GoogleDriveMyDriveRoot = $GoogleDriveMyDriveRoot
    }
    if ($GoogleDriveCandidates) {
        $projectDataArguments.GoogleDriveCandidates = $GoogleDriveCandidates
    }
    if ($ProjectDataEnvironmentReadOperation) {
        $projectDataArguments.ReadUserEnvironment = $ProjectDataEnvironmentReadOperation
    }
    if ($ProjectDataEnvironmentWriteOperation) {
        $projectDataArguments.WriteUserEnvironment = $ProjectDataEnvironmentWriteOperation
    }
    $projectDataResult = & (Join-Path $CapsuleRoot 'tools\Set-ProjectDataEnvironment.ps1') @projectDataArguments
}

$pointer = Get-Content -LiteralPath (Join-Path $CapsuleRoot 'manifests\capsule.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
$portableAgents = Resolve-ContainedCapsulePath `
    -Root $CapsuleRoot `
    -RelativePath ([string]$pointer.harnessRelativePath)
$agentsStage = Join-Path $UserRoot ('.agents.install-' + [Guid]::NewGuid().ToString('N'))
$harnessBackupRoot = $null

New-Item -ItemType Directory -Path $UserRoot -Force | Out-Null
Copy-Item -LiteralPath $portableAgents -Destination $agentsStage -Recurse
try {
    if (Test-Path -LiteralPath $agentsTarget) {
        $agentsItem = Get-Item -LiteralPath $agentsTarget -Force
        if (($agentsItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Shared harness target must not be a reparse point: $agentsTarget"
        }
        $harnessBackupRoot = Join-Path $UserRoot (
            '.agents-backups\' +
            (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss') +
            '_' +
            [Guid]::NewGuid().ToString('N')
        )
        New-Item -ItemType Directory -Path (Split-Path -Parent $harnessBackupRoot) -Force | Out-Null
        Move-Item -LiteralPath $agentsTarget -Destination $harnessBackupRoot
    }
    Move-Item -LiteralPath $agentsStage -Destination $agentsTarget
}
catch {
    if (Test-Path -LiteralPath $agentsStage) {
        Remove-Item -LiteralPath $agentsStage -Recurse -Force
    }
    if ($harnessBackupRoot -and
        -not (Test-Path -LiteralPath $agentsTarget) -and
        (Test-Path -LiteralPath $harnessBackupRoot)) {
        Move-Item -LiteralPath $harnessBackupRoot -Destination $agentsTarget
        $harnessBackupRoot = $null
    }
    throw
}

$obsidianResult = $null
if (-not $SkipObsidianConfig -and
    -not [string]::IsNullOrWhiteSpace([string]$pointer.obsidianConfigRelativePath)) {
    $portableObsidian = Resolve-ContainedCapsulePath `
        -Root $CapsuleRoot `
        -RelativePath ([string]$pointer.obsidianConfigRelativePath)
    $restoreArguments = @{
        SourceRoot = $portableObsidian
        ObsidianRegistryPath = $ObsidianRegistryPath
    }
    if ($ObsidianVaultRoot) {
        $restoreArguments.VaultRoot = $ObsidianVaultRoot
    }
    $obsidianResult = & (Join-Path $CapsuleRoot 'tools\Restore-ObsidianConfig.ps1') @restoreArguments
}

[pscustomobject]@{
    Result = 'PASS'
    UserRoot = $UserRoot
    PayloadKind = 'global-harness'
    HarnessTarget = $agentsTarget
    HarnessBackupRoot = $harnessBackupRoot
    ObsidianVaultRoot = if ($obsidianResult) { $obsidianResult.VaultRoot } else { $null }
    ObsidianBackupRoot = if ($obsidianResult) { $obsidianResult.BackupRoot } else { $null }
    ProjectDataEnvironmentMode = if ($projectDataResult) { $projectDataResult.Mode } else { 'SKIPPED' }
    ProjectDataSyncRoot = if ($projectDataResult) { $projectDataResult.ProjectDataSyncRoot } else { $null }
    ProjectDataRoot = if ($projectDataResult) { $projectDataResult.ProjectDataRoot } else { $null }
    QuickAccessChanged = $false
    NextStep = 'Run repository discovery to clone or update project repositories.'
}
}
finally {
    $bootstrapLock.Dispose()
}
