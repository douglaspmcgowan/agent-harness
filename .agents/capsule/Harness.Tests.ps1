[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$subject = Join-Path $PSScriptRoot 'Harness.ps1'
$testRoot = Join-Path $env:TEMP ('capsule-harness-test-' + [Guid]::NewGuid().ToString('N'))

try {
    $capsule = Join-Path $testRoot 'Capsule With Spaces'
    $tools = Join-Path $capsule 'tools'
    $userRoot = Join-Path $testRoot 'Receiving User'
    $harnessRepository = Join-Path $testRoot 'Harness Repository'
    $log = Join-Path $testRoot 'calls.txt'
    New-Item -ItemType Directory -Path $tools, $userRoot, $harnessRepository -Force | Out-Null
    [System.IO.File]::WriteAllText($log, '')

    $toolBodies = @{
        'Verify-Capsule.ps1' = @'
param([string]$CapsuleRoot, [string]$TrustedHarnessRepository)
[System.IO.File]::AppendAllText($env:CAPSULE_TEST_LOG, 'verify' + [Environment]::NewLine)
[pscustomobject]@{ Result = 'PASS' }
'@
        'Refresh-Capsule.ps1' = @'
param(
    [string]$CapsuleRoot,
    [string]$HarnessRepository,
    [string]$AccountMapPath,
    [string]$ObsidianVaultRoot,
    [string]$ObsidianRegistryPath,
    [switch]$SkipObsidianConfig
)
if ($PSBoundParameters.ContainsKey('SnapshotRoot')) { throw 'sync still passed a workspace snapshot' }
[System.IO.File]::AppendAllText($env:CAPSULE_TEST_LOG, 'refresh' + [Environment]::NewLine)
'@
        'Bootstrap-Capsule.ps1' = @'
param(
    [string]$CapsuleRoot,
    [string]$UserRoot,
    [string]$TrustedHarnessRepository,
    [string]$ObsidianVaultRoot,
    [string]$ObsidianRegistryPath,
    [string]$GoogleDriveMyDriveRoot,
    [string[]]$GoogleDriveCandidates,
    [switch]$SkipObsidianConfig,
    [switch]$SkipProjectDataEnvironment,
    [switch]$ProjectDataEnvironmentDryRun,
    [switch]$SkipPackageInstall,
    [switch]$SkipAccountLogin,
    [switch]$SkipQuickAccess
)
[System.IO.File]::AppendAllText($env:CAPSULE_TEST_LOG, 'install' + [Environment]::NewLine)
'@
    }
    foreach ($entry in $toolBodies.GetEnumerator()) {
        [System.IO.File]::WriteAllText(
            (Join-Path $tools $entry.Key),
            $entry.Value,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    $packagedSubject = Join-Path $capsule 'Harness.ps1'
    Copy-Item -LiteralPath $subject -Destination $packagedSubject

    $env:CAPSULE_TEST_LOG = $log
    & $packagedSubject -Action verify -CapsuleRoot $capsule | Out-Null
    & $packagedSubject `
        -Action sync `
        -CapsuleRoot $capsule `
        -HarnessRepository $harnessRepository `
        -SkipObsidianConfig | Out-Null
    & $packagedSubject `
        -Action install `
        -CapsuleRoot $capsule `
        -UserRoot $userRoot `
        -GoogleDriveMyDriveRoot (Join-Path $testRoot 'My Drive') `
        -SkipPackageInstall `
        -SkipAccountLogin `
        -SkipObsidianConfig | Out-Null

    $calls = Get-Content -LiteralPath $log
    $expected = @('verify', 'refresh', 'verify', 'verify', 'install')
    if (Compare-Object -ReferenceObject $expected -DifferenceObject $calls -SyncWindow 0) {
        throw "Unexpected Harness.ps1 dispatch sequence: $($calls -join ', ')"
    }

    foreach ($retiredAction in @('backup', 'restore')) {
        $rejected = $false
        try {
            & $packagedSubject -Action $retiredAction -CapsuleRoot $capsule | Out-Null
        }
        catch {
            $rejected = $true
        }
        if (-not $rejected) {
            throw "Capsule Harness still exposes project workspace action: $retiredAction"
        }
    }

    $sourceRoot = Join-Path $testRoot 'source'
    $sourceCapsule = Join-Path $sourceRoot 'capsule'
    New-Item -ItemType Directory -Path $sourceCapsule -Force | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $sourceCapsule 'Verify-Capsule.ps1'),
        @'
param([string]$CapsuleRoot, [string]$TrustedHarnessRepository)
[System.IO.File]::AppendAllText($env:CAPSULE_TEST_LOG, 'source-verify' + [Environment]::NewLine)
[pscustomobject]@{ Result = 'PASS' }
'@,
        [System.Text.UTF8Encoding]::new($false)
    )

    [System.IO.File]::WriteAllText($log, '')
    & $packagedSubject -Action verify -CapsuleRoot $capsule -SourceRoot $sourceRoot | Out-Null
    & $packagedSubject -Action verify -CapsuleRoot $capsule | Out-Null
    $resolutionCalls = Get-Content -LiteralPath $log
    if (Compare-Object -ReferenceObject @('source-verify', 'verify') -DifferenceObject $resolutionCalls -SyncWindow 0) {
        throw "Unexpected Capsule tool resolution sequence: $($resolutionCalls -join ', ')"
    }

    $canonicalAgents = Join-Path $testRoot 'canonical\.agents'
    $canonicalCapsule = Join-Path $canonicalAgents 'capsule'
    $canonicalTools = Join-Path $canonicalAgents 'tools'
    New-Item -ItemType Directory -Path $canonicalCapsule, $canonicalTools -Force | Out-Null
    Copy-Item -LiteralPath $subject -Destination (Join-Path $canonicalCapsule 'Harness.ps1')
    [System.IO.File]::WriteAllText(
        (Join-Path $canonicalCapsule 'Verify-Capsule.ps1'),
        @'
param([string]$CapsuleRoot, [string]$TrustedHarnessRepository)
[System.IO.File]::AppendAllText($env:CAPSULE_TEST_LOG, 'auto-source-verify' + [Environment]::NewLine)
[pscustomobject]@{ Result = 'PASS' }
'@,
        [System.Text.UTF8Encoding]::new($false)
    )

    [System.IO.File]::WriteAllText($log, '')
    & (Join-Path $canonicalCapsule 'Harness.ps1') -Action verify -CapsuleRoot $capsule | Out-Null
    $autoResolutionCalls = Get-Content -LiteralPath $log
    if (Compare-Object -ReferenceObject @('auto-source-verify') -DifferenceObject $autoResolutionCalls -SyncWindow 0) {
        throw "Canonical Harness.ps1 selected a stale packaged tool: $($autoResolutionCalls -join ', ')"
    }

    'Capsule Harness global-only entrypoint tests passed.'
}
finally {
    Remove-Item Env:CAPSULE_TEST_LOG -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
