$ErrorActionPreference = 'Stop'

$validator = Join-Path $PSScriptRoot 'Test-DataManifest.ps1'
$root = Join-Path $env:TEMP ('test-data-manifest-' + [Guid]::NewGuid().ToString('N'))
$adapterRoot = Join-Path $root 'adapters'
$projectAdapterRoot = Join-Path $root '.agents\data'
$manifestPath = Join-Path $root 'data-manifest.yaml'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-ManifestValidator(
    [string]$Manifest,
    [string]$SharedRoot = $adapterRoot,
    [string]$ProjectRoot = $projectAdapterRoot
) {
    [System.IO.File]::WriteAllText(
        $manifestPath,
        $Manifest.Trim() + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'powershell.exe'
    $startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$validator`" -ManifestPath `"$manifestPath`" -AdapterRoot `"$SharedRoot`" -ProjectAdapterRoot `"$ProjectRoot`""
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return @{
        ExitCode = $process.ExitCode
        Output = ($stdout + $stderr)
    }
}

function Assert-Passes([string]$Name, [string]$Manifest) {
    $result = Invoke-ManifestValidator $Manifest
    Assert-True ($result.ExitCode -eq 0) "$Name failed unexpectedly:`n$($result.Output)"
}

function Assert-Fails([string]$Name, [string]$Manifest, [string]$Pattern) {
    $result = Invoke-ManifestValidator $Manifest
    Assert-True ($result.ExitCode -ne 0) "$Name unexpectedly passed."
    Assert-True ($result.Output -match $Pattern) "$Name did not report '$Pattern':`n$($result.Output)"
}

function Assert-FailsWithRoots(
    [string]$Name,
    [string]$Manifest,
    [string]$SharedRoot,
    [string]$ProjectRoot,
    [string]$Pattern
) {
    $result = Invoke-ManifestValidator $Manifest $SharedRoot $ProjectRoot
    Assert-True ($result.ExitCode -ne 0) "$Name unexpectedly passed."
    Assert-True ($result.Output -match $Pattern) "$Name did not report '$Pattern':`n$($result.Output)"
}

$validAsset = @'
version: 2
project: "sample"
data_root_env: "PROJECT_DATA_ROOT"
assets:
  - id: "sample-database"
    project: "sample"
    class: "local-transactional-state"
    authority: "local SQLite database"
    local_destination: "runtime/sample.sqlite"
    adapter: "ReviewedAdapter.ps1"
    version_rule: "latest verified generation"
    integrity_rule: "SHA-256 plus SQLite integrity_check"
    restore_verifier: "open restored database and run integrity_check"
    recovery_rule: "database-native export retained off-site"
    retention_daily: 3
    retention_weekly: 4
    retention_monthly: 3
    stale_write_rule: "single-writer-lease"
'@

try {
    New-Item -ItemType Directory -Path $adapterRoot, $projectAdapterRoot -Force | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $adapterRoot 'ReviewedAdapter.ps1'),
        "param()`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    Assert-Passes 'schema v2 empty asset list' @'
version: 2
project: "sample"
data_root_env: "PROJECT_DATA_ROOT"
assets: []
'@

    Assert-Passes 'legacy v1 empty asset list' @'
version: 1
project: "sample"
data_root_env: "PROJECT_DATA_ROOT"
assets: []
'@

    Assert-Passes 'complete stateful asset' $validAsset
    [System.IO.File]::WriteAllText(
        (Join-Path $projectAdapterRoot 'Sync-ProjectData.ps1'),
        "param()`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Assert-Passes 'reviewed repository-relative project adapter' (
        $validAsset.Replace('ReviewedAdapter.ps1', '.agents/data/Sync-ProjectData.ps1')
    )

    $externalShared = Join-Path $root 'external-shared'
    $sharedJunction = Join-Path $root 'shared-junction'
    New-Item -ItemType Directory -Path $externalShared -Force | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $externalShared 'ReviewedAdapter.ps1'),
        "param()`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    New-Item -ItemType Junction -Path $sharedJunction -Target $externalShared | Out-Null
    Assert-FailsWithRoots `
        'shared adapter through reparse ancestor' `
        $validAsset `
        $sharedJunction `
        $projectAdapterRoot `
        'reparse point'

    $sharedCandidate = Join-Path $adapterRoot 'LinkedAdapter.ps1'
    New-Item -ItemType Junction -Path $sharedCandidate -Target $externalShared | Out-Null
    Assert-FailsWithRoots `
        'shared adapter reparse candidate' `
        ($validAsset.Replace('ReviewedAdapter.ps1', 'LinkedAdapter.ps1')) `
        $adapterRoot `
        $projectAdapterRoot `
        'reparse point'

    $externalProject = Join-Path $root 'external-project'
    $projectNested = Join-Path $projectAdapterRoot 'linked'
    New-Item -ItemType Directory -Path $externalProject -Force | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $externalProject 'Sync-ProjectData.ps1'),
        "param()`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    New-Item -ItemType Junction -Path $projectNested -Target $externalProject | Out-Null
    Assert-FailsWithRoots `
        'project adapter through reparse ancestor' `
        ($validAsset.Replace('ReviewedAdapter.ps1', '.agents/data/linked/Sync-ProjectData.ps1')) `
        $adapterRoot `
        $projectAdapterRoot `
        'reparse point'

    $projectCandidate = Join-Path $projectAdapterRoot 'LinkedProjectAdapter.ps1'
    New-Item -ItemType Junction -Path $projectCandidate -Target $externalProject | Out-Null
    Assert-FailsWithRoots `
        'project adapter reparse candidate' `
        ($validAsset.Replace('ReviewedAdapter.ps1', '.agents/data/LinkedProjectAdapter.ps1')) `
        $adapterRoot `
        $projectAdapterRoot `
        'reparse point'

    Assert-Fails 'malformed field syntax' ($validAsset.Replace('version: 2', 'version 2')) 'Malformed manifest line'
    Assert-Fails 'missing manifest project' ($validAsset -replace '(?m)^project:.*\r?\n', '') 'Manifest is missing required field: project'
    Assert-Fails 'legacy populated manifest' ($validAsset.Replace('version: 2', 'version: 1')) 'version 2'
    Assert-Fails 'unsupported manifest version' ($validAsset.Replace('version: 2', 'version: 99')) 'Unsupported manifest version'
    Assert-Fails 'missing authority' ($validAsset -replace '(?m)^\s+authority:.*\r?\n', '') 'authority'
    Assert-Fails 'unsupported class' ($validAsset.Replace('local-transactional-state', 'mystery-state')) 'Unsupported asset class'
    Assert-Fails 'missing adapter declaration' ($validAsset -replace '(?m)^\s+adapter:.*\r?\n', '') 'adapter'
    Assert-Fails 'unresolved adapter' ($validAsset.Replace('ReviewedAdapter.ps1', 'MissingAdapter.ps1')) 'does not resolve'
    Assert-Fails 'project adapter path traversal' (
        $validAsset.Replace('ReviewedAdapter.ps1', '.agents/data/../escape.ps1')
    ) 'malformed adapter|does not resolve'
    Assert-Fails 'path traversal destination' ($validAsset.Replace('runtime/sample.sqlite', '../escape.sqlite')) 'unsafe local_destination'
    Assert-Fails 'absolute destination' ($validAsset.Replace('runtime/sample.sqlite', 'C:\\escape.sqlite')) 'unsafe local_destination'
    Assert-Fails 'missing recovery metadata' ($validAsset -replace '(?m)^\s+recovery_rule:.*\r?\n', '') 'recovery_rule'
    Assert-Fails 'partial retention override' ($validAsset -replace '(?m)^\s+retention_monthly:.*\r?\n', '') 'all three retention fields'
    Assert-Fails 'negative retention override' ($validAsset.Replace('retention_daily: 3', 'retention_daily: -1')) 'invalid retention_daily'
    Assert-Passes 'large retention override' ($validAsset.Replace('retention_weekly: 4', 'retention_weekly: 101'))
    Assert-Passes 'newest-only retention override' (
        $validAsset.Replace('retention_daily: 3', 'retention_daily: 0').
            Replace('retention_weekly: 4', 'retention_weekly: 0').
            Replace('retention_monthly: 3', 'retention_monthly: 0')
    )
    Assert-Fails 'missing stale-write metadata' ($validAsset -replace '(?m)^\s+stale_write_rule:.*(?:\r?\n|$)', '') 'stale_write_rule'
    Assert-Fails 'unknown stale-write policy' ($validAsset.Replace('single-writer-lease', 'last-write-wins')) 'Unsupported stale_write_rule'
    Assert-Fails 'asset project mismatch' ($validAsset.Replace('    project: "sample"', '    project: "other"')) 'must match manifest project'
    Assert-Fails 'unknown field' ($validAsset.Replace('    authority:', "    mystery_field: `"x`"`r`n    authority:")) 'Unsupported asset field'

    $regenerable = @'
version: 2
project: "sample"
data_root_env: "PROJECT_DATA_ROOT"
assets:
  - id: "compiled-output"
    project: "sample"
    class: "regenerable-output"
    authority: "committed source"
    local_destination: "outputs/compiled"
    adapter: "ReviewedAdapter.ps1"
    version_rule: "Git revision"
    integrity_rule: "SHA-256"
    restore_verifier: "compare rebuilt output"
'@
    Assert-Fails 'missing regeneration metadata' $regenerable 'regeneration_rule'

    Write-Output 'Test-DataManifest tests passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
