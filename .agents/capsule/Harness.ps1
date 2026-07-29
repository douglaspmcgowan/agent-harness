[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('install', 'sync', 'verify')]
    [string]$Action,
    [string]$CapsuleRoot = $PSScriptRoot,
    [string]$SourceRoot,
    [string]$UserRoot = $env:USERPROFILE,
    [string]$HarnessRepository = (Join-Path $env:USERPROFILE 'projects\agent-harness'),
    [string]$AccountMapPath,
    [string]$ObsidianVaultRoot,
    [string]$ObsidianRegistryPath = (Join-Path $env:APPDATA 'obsidian\obsidian.json'),
    [string]$GoogleDriveMyDriveRoot,
    [string[]]$GoogleDriveCandidates,
    [switch]$SkipObsidianConfig,
    [switch]$SkipProjectDataEnvironment,
    [switch]$ProjectDataEnvironmentDryRun,
    [switch]$SkipPackageInstall,
    [switch]$SkipAccountLogin,
    [switch]$SkipQuickAccess
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $canonicalSourceCandidate = Split-Path -Parent $PSScriptRoot
    $canonicalCapsuleCandidate = Join-Path $canonicalSourceCandidate 'capsule'
    if (
        [string]::Equals(
            (Split-Path -Leaf $canonicalSourceCandidate),
            '.agents',
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $canonicalCapsuleCandidate -PathType Container) -and
        [string]::Equals(
            (Resolve-Path -LiteralPath $canonicalCapsuleCandidate).Path,
            (Resolve-Path -LiteralPath $PSScriptRoot).Path,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        $SourceRoot = $canonicalSourceCandidate
    }
}

function Resolve-CapsuleTool {
    param([string]$Name)

    $candidates = @()
    if ($SourceRoot) {
        $candidates += @(
            (Join-Path $SourceRoot ("capsule\" + $Name)),
            (Join-Path $SourceRoot ("tools\" + $Name))
        )
    }
    $candidates += @(
        (Join-Path $CapsuleRoot ("tools\" + $Name)),
        (Join-Path $CapsuleRoot $Name)
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    throw "Capsule tool is unavailable: $Name"
}

function Invoke-CapsuleVerify {
    $verify = Resolve-CapsuleTool -Name 'Verify-Capsule.ps1'
    & $verify `
        -CapsuleRoot $CapsuleRoot `
        -TrustedHarnessRepository $HarnessRepository
}

switch ($Action) {
    'verify' {
        Invoke-CapsuleVerify
    }
    'sync' {
        if ($PSBoundParameters.ContainsKey('ObsidianVaultRoot') -or
            $PSBoundParameters.ContainsKey('ObsidianRegistryPath')) {
            throw 'Capsule sync uses the committed approved Obsidian snapshot. Run Capture-ApprovedObsidianConfig.ps1 before committing when settings change.'
        }
        $arguments = @{
            CapsuleRoot = $CapsuleRoot
            HarnessRepository = $HarnessRepository
            SkipObsidianConfig = $SkipObsidianConfig
        }
        if ($AccountMapPath) {
            $arguments.AccountMapPath = $AccountMapPath
        }
        & (Resolve-CapsuleTool -Name 'Refresh-Capsule.ps1') @arguments | Out-Null
        Invoke-CapsuleVerify
    }
    'install' {
        Invoke-CapsuleVerify | Out-Null
        $arguments = @{
            CapsuleRoot = $CapsuleRoot
            UserRoot = $UserRoot
            TrustedHarnessRepository = $HarnessRepository
            ObsidianRegistryPath = $ObsidianRegistryPath
            SkipObsidianConfig = $SkipObsidianConfig
            SkipProjectDataEnvironment = $SkipProjectDataEnvironment
            ProjectDataEnvironmentDryRun = $ProjectDataEnvironmentDryRun
            SkipPackageInstall = $SkipPackageInstall
            SkipAccountLogin = $SkipAccountLogin
            SkipQuickAccess = $SkipQuickAccess
        }
        if ($ObsidianVaultRoot) {
            $arguments.ObsidianVaultRoot = $ObsidianVaultRoot
        }
        if ($GoogleDriveMyDriveRoot) {
            $arguments.GoogleDriveMyDriveRoot = $GoogleDriveMyDriveRoot
        }
        if ($GoogleDriveCandidates) {
            $arguments.GoogleDriveCandidates = $GoogleDriveCandidates
        }
        & (Resolve-CapsuleTool -Name 'Bootstrap-Capsule.ps1') @arguments
    }
}
