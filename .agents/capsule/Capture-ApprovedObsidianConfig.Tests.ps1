[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$captureSource = Join-Path $PSScriptRoot 'Capture-ApprovedObsidianConfig.ps1'
$exportSource = Join-Path $PSScriptRoot 'Export-ObsidianConfig.ps1'
$testRoot = Join-Path $env:TEMP ('approved-obsidian-capture-' + [Guid]::NewGuid().ToString('N'))

function Write-Utf8 {
    param([string]$Path, [string]$Value)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($false))
}

try {
    $repository = Join-Path $testRoot 'Harness Repository With Spaces'
    $capsule = Join-Path $repository '.agents\capsule'
    $vault = Join-Path $testRoot 'Vault With Spaces'
    $registry = Join-Path $testRoot 'Roaming With Spaces\obsidian\obsidian.json'
    New-Item -ItemType Directory -Path $capsule -Force | Out-Null
    Copy-Item -LiteralPath $captureSource, $exportSource -Destination $capsule
    & git init $repository | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Capture fixture Git initialization failed.' }

    Write-Utf8 -Path (Join-Path $vault '.obsidian\app.json') -Value "{`"fixture`":true}`n"
    Write-Utf8 -Path (Join-Path $vault '.obsidian\community-plugins.json') -Value "[`"calendar`"]`n"
    Write-Utf8 -Path (Join-Path $vault '.obsidian\workspace.json') -Value "{`"exclude`":true}`n"
    Write-Utf8 -Path (Join-Path $vault '26_Sensitive\must-not-read.txt') -Value "forbidden`n"
    Write-Utf8 -Path $registry -Value (([ordered]@{
        vaults = [ordered]@{
            active = [ordered]@{ path = $vault; open = $true }
        }
    } | ConvertTo-Json -Depth 5) + [Environment]::NewLine)

    $result = & (Join-Path $capsule 'Capture-ApprovedObsidianConfig.ps1') `
        -HarnessRepository $repository `
        -ObsidianRegistryPath $registry
    if ($result.Result -ne 'PASS') {
        throw 'Approved Obsidian configuration capture did not report PASS.'
    }

    $approved = Join-Path $capsule 'approved-obsidian-config'
    $snapshot = Get-Content -LiteralPath (Join-Path $approved 'snapshot.json') -Raw -Encoding UTF8 |
        ConvertFrom-Json
    foreach ($record in @($snapshot.files)) {
        $path = Join-Path (Join-Path $approved 'files') ([string]$record.path)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-Item -LiteralPath $path).Length -ne [long]$record.bytes -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne
                [string]$record.sha256) {
            throw "Captured approved snapshot digest failed: $($record.path)"
        }
    }
    if ((Test-Path -LiteralPath (Join-Path $approved 'files\workspace.json')) -or
        (Test-Path -LiteralPath (Join-Path $approved 'files\26_Sensitive'))) {
        throw 'Capture included configuration outside the approved allowlist.'
    }
    $status = @(& git -C $repository status --short -- .agents/capsule/approved-obsidian-config)
    if ($LASTEXITCODE -ne 0 -or $status.Count -eq 0) {
        throw 'Capture did not leave the approved snapshot as a deliberate Git change for review.'
    }

    [pscustomobject]@{
        Result = 'PASS'
        SafeAllowlist = $true
        DigestManifest = $true
        PathsWithSpaces = $true
        DeliberateGitChange = $true
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [System.IO.Path]::GetFullPath($testRoot)
        if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
