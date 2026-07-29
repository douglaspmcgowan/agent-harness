[CmdletBinding()]
param(
    [string]$HarnessRepository = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$VaultRoot,
    [string]$ObsidianRegistryPath = (Join-Path $env:APPDATA 'obsidian\obsidian.json')
)

$ErrorActionPreference = 'Stop'

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

$repositoryFull = [System.IO.Path]::GetFullPath($HarnessRepository)
Assert-NoReparseAncestors -Path $repositoryFull -Label 'Harness repository'
if (-not (Test-Path -LiteralPath (Join-Path $repositoryFull '.git'))) {
    throw "Approved Obsidian configuration capture requires a Git harness worktree: $repositoryFull"
}
$capsuleSource = Join-Path $repositoryFull '.agents\capsule'
$exporter = Join-Path $capsuleSource 'Export-ObsidianConfig.ps1'
if (-not (Test-Path -LiteralPath $exporter -PathType Leaf)) {
    throw "Obsidian configuration exporter is unavailable: $exporter"
}

$target = Join-Path $capsuleSource 'approved-obsidian-config'
$parent = Split-Path -Parent $target
$stage = Join-Path $parent ('.approved-obsidian-config.capture-' + [Guid]::NewGuid().ToString('N'))
$previous = $null
$installed = $false
try {
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $exportArguments = @{
        DestinationRoot = (Join-Path $stage 'files')
        ObsidianRegistryPath = $ObsidianRegistryPath
    }
    if ($VaultRoot) {
        $exportArguments.VaultRoot = $VaultRoot
    }
    & $exporter @exportArguments | Out-Null

    $filesRoot = Join-Path $stage 'files'
    $records = @(Get-ChildItem -LiteralPath $filesRoot -File -Recurse -Force |
        Sort-Object FullName |
        ForEach-Object {
            [ordered]@{
                path = $_.FullName.Substring($filesRoot.Length).TrimStart('\').Replace('\', '/')
                bytes = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        })
    [System.IO.File]::WriteAllText(
        (Join-Path $stage 'snapshot.json'),
        (([ordered]@{
            schemaVersion = 1
            purpose = 'Approved portable Obsidian configuration captured for the next harness commit.'
            capturedAt = (Get-Date).ToUniversalTime().ToString('o')
            files = $records
        }) | ConvertTo-Json -Depth 6) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    $gitleaks = Get-Command gitleaks.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $gitleaks) {
        $gitleaks = Get-Command gitleaks -CommandType Application -ErrorAction SilentlyContinue
    }
    if (-not $gitleaks) {
        throw 'Gitleaks is required before approved Obsidian configuration can be captured.'
    }
    & $gitleaks.Source dir --no-banner --redact --exit-code 1 $stage
    if ($LASTEXITCODE -ne 0) {
        throw 'Gitleaks blocked the approved Obsidian configuration capture.'
    }

    if (Test-Path -LiteralPath $target) {
        Assert-NoReparseAncestors -Path $target -Label 'Approved Obsidian configuration target'
        $previous = Join-Path $parent ('.approved-obsidian-config.previous-' + [Guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $target -Destination $previous
    }
    try {
        Move-Item -LiteralPath $stage -Destination $target
        $installed = $true
    }
    catch {
        if ($previous -and
            -not (Test-Path -LiteralPath $target) -and
            (Test-Path -LiteralPath $previous)) {
            Move-Item -LiteralPath $previous -Destination $target
        }
        throw
    }
    if ($previous) {
        Remove-Item -LiteralPath $previous -Recurse -Force
    }

    [pscustomobject]@{
        Result = 'PASS'
        ApprovedSnapshotRoot = $target
        Files = $records.Count
        NextStep = 'Review the diff, run verification, then commit and push the approved snapshot.'
    }
}
finally {
    if (-not $installed -and (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
