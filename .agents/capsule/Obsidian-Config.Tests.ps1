[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$export = Join-Path $PSScriptRoot 'Export-ObsidianConfig.ps1'
$restore = Join-Path $PSScriptRoot 'Restore-ObsidianConfig.ps1'
$testRoot = Join-Path $env:TEMP ('obsidian-config-test-' + [Guid]::NewGuid().ToString('N'))

function Write-Utf8 {
    param([string]$Path, [string]$Value)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($false))
}

try {
    $sourceVault = Join-Path $testRoot 'Vault Source With Spaces'
    $targetVault = Join-Path $testRoot 'Vault Target With Spaces'
    $exportRoot = Join-Path $testRoot 'Portable Config With Spaces'
    $registryPath = Join-Path $testRoot 'Roaming Profile\obsidian\obsidian.json'
    $config = Join-Path $sourceVault '.obsidian'

    $safeFiles = [ordered]@{
        'app.json' = '{"source":"app"}'
        'appearance.json' = '{"source":"appearance"}'
        'core-plugins.json' = '["file-explorer"]'
        'hotkeys.json' = '{}'
        'graph.json' = '{}'
        'types.json' = '{}'
        'community-plugins.json' = '["calendar","dataview"]'
        'snippets\one.css' = 'body { color: red; }'
        'themes\Theme One\manifest.json' = '{"name":"Theme One"}'
        'themes\Theme One\theme.css' = 'body { color: blue; }'
    }
    foreach ($entry in $safeFiles.GetEnumerator()) {
        Write-Utf8 -Path (Join-Path $config $entry.Key) -Value ($entry.Value + [Environment]::NewLine)
    }

    foreach ($unsafe in @(
        'workspace.json',
        'bookmarks.json',
        'sync.json',
        'core-plugins-migration.json',
        'plugins\calendar\data.json',
        'plugins\calendar\main.js',
        'snippets\ignore.txt',
        'themes\Theme One\cache.json'
    )) {
        Write-Utf8 -Path (Join-Path $config $unsafe) -Value "unsafe`n"
    }
    Write-Utf8 -Path (Join-Path $sourceVault 'AI Reference\must-not-read.txt') -Value "forbidden`n"
    Write-Utf8 -Path (Join-Path $sourceVault '40_Reference\AI Reference.md') -Value "forbidden`n"
    Write-Utf8 -Path (Join-Path $sourceVault '26_Sensitive\must-not-read.txt') -Value "forbidden`n"
    Write-Utf8 -Path (Join-Path $sourceVault '31_Business\Other People Reference.md') -Value "forbidden`n"
    Write-Utf8 -Path $registryPath -Value (([ordered]@{
        vaults = [ordered]@{
            closed = [ordered]@{ path = (Join-Path $testRoot 'Closed Vault'); open = $false }
            active = [ordered]@{ path = $sourceVault; open = $true }
        }
    } | ConvertTo-Json -Depth 5) + [Environment]::NewLine)

    $exportResult = & $export -DestinationRoot $exportRoot -ObsidianRegistryPath $registryPath
    if (-not [string]::Equals(
        [System.IO.Path]::GetFullPath($exportResult.VaultRoot),
        [System.IO.Path]::GetFullPath($sourceVault),
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Exporter did not resolve the active vault from obsidian.json.'
    }

    $exportedRelative = @(Get-ChildItem -LiteralPath $exportRoot -File -Recurse -Force |
        ForEach-Object { $_.FullName.Substring($exportRoot.Length).TrimStart('\') })
    $expectedRelative = @($safeFiles.Keys) + 'manifest.json'
    if (Compare-Object -ReferenceObject $expectedRelative -DifferenceObject $exportedRelative) {
        throw "Exporter copied the wrong files: $($exportedRelative -join ', ')"
    }
    $exportedPluginIds = Get-Content -LiteralPath (Join-Path $exportRoot 'community-plugins.json') -Raw |
        ConvertFrom-Json
    if (@($exportedPluginIds | Where-Object { $_ -isnot [string] }).Count -ne 0) {
        throw 'Community plugin portability data contains something other than plugin IDs.'
    }

    $singlePluginExport = Join-Path $testRoot 'Single Plugin Export'
    Write-Utf8 -Path (Join-Path $config 'community-plugins.json') -Value "[`"calendar`"]`n"
    & $export -DestinationRoot $singlePluginExport -ObsidianRegistryPath $registryPath | Out-Null
    $singlePluginJson = Get-Content -LiteralPath (Join-Path $singlePluginExport 'community-plugins.json') -Raw
    if (-not $singlePluginJson.TrimStart().StartsWith('[')) {
        throw 'Exporter collapsed a one-entry community plugin ID array into a scalar.'
    }

    Write-Utf8 -Path (Join-Path $targetVault '.obsidian\app.json') -Value "{`"target`":`"old`"}`n"
    Write-Utf8 -Path (Join-Path $targetVault '.obsidian\plugins\calendar\data.json') -Value "{`"preserve`":true}`n"
    $restoreResult = & $restore -SourceRoot $exportRoot -VaultRoot $targetVault
    if ((Get-Content -LiteralPath (Join-Path $targetVault '.obsidian\app.json') -Raw) -notmatch '"source":"app"') {
        throw 'Restore did not apply the portable app configuration.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $targetVault '.obsidian\plugins\calendar\data.json') -PathType Leaf)) {
        throw 'Restore removed receiving-vault plugin data outside the allowlist.'
    }
    $backup = Join-Path $restoreResult.BackupRoot 'app.json'
    if (-not (Test-Path -LiteralPath $backup -PathType Leaf) -or
        (Get-Content -LiteralPath $backup -Raw) -notmatch '"target":"old"') {
        throw 'Restore did not back up an overwritten configuration file.'
    }

    $restoreLockTarget = [System.IO.Path]::GetFullPath((Join-Path $targetVault '.obsidian')).TrimEnd('\').ToLowerInvariant()
    $restoreLockSha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $restoreLockHash = ([BitConverter]::ToString(
            $restoreLockSha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($restoreLockTarget))
        )).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $restoreLockSha.Dispose()
    }
    $restoreLockDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'AgentHarness-ObsidianConfigLocks'
    New-Item -ItemType Directory -Path $restoreLockDirectory -Force | Out-Null
    $heldRestoreLock = [System.IO.File]::Open(
        (Join-Path $restoreLockDirectory ($restoreLockHash + '.lock')),
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    $overlappingRestoreRejected = $false
    try {
        try {
            & $restore -SourceRoot $exportRoot -VaultRoot $targetVault | Out-Null
        }
        catch {
            $overlappingRestoreRejected = $true
        }
    }
    finally {
        $heldRestoreLock.Dispose()
    }
    if (-not $overlappingRestoreRejected) {
        throw 'Restore accepted an overlapping operation for the same vault configuration.'
    }

    $exportJunctionVault = Join-Path $testRoot 'Export Junction Vault'
    $exportJunctionExternal = Join-Path $testRoot 'Export Junction External'
    New-Item -ItemType Directory -Path (Join-Path $exportJunctionVault '.obsidian'), $exportJunctionExternal -Force |
        Out-Null
    Write-Utf8 -Path (Join-Path $exportJunctionExternal 'external.css') -Value "external`n"
    New-Item `
        -ItemType Junction `
        -Path (Join-Path $exportJunctionVault '.obsidian\snippets') `
        -Target $exportJunctionExternal | Out-Null
    $exportJunctionRejected = $false
    try {
        & $export `
            -DestinationRoot (Join-Path $testRoot 'Junction Export') `
            -VaultRoot $exportJunctionVault | Out-Null
    }
    catch {
        $exportJunctionRejected = $true
    }
    if (-not $exportJunctionRejected) {
        throw 'Exporter followed a snippets junction outside the active vault configuration.'
    }

    $restoreJunctionVault = Join-Path $testRoot 'Restore Junction Vault'
    $restoreJunctionExternal = Join-Path $testRoot 'Restore Junction External'
    New-Item -ItemType Directory -Path (Join-Path $restoreJunctionVault '.obsidian'), $restoreJunctionExternal -Force |
        Out-Null
    New-Item `
        -ItemType Junction `
        -Path (Join-Path $restoreJunctionVault '.obsidian\snippets') `
        -Target $restoreJunctionExternal | Out-Null
    $restoreJunctionRejected = $false
    try {
        & $restore -SourceRoot $exportRoot -VaultRoot $restoreJunctionVault | Out-Null
    }
    catch {
        $restoreJunctionRejected = $true
    }
    if (-not $restoreJunctionRejected -or
        (Test-Path -LiteralPath (Join-Path $restoreJunctionExternal 'one.css'))) {
        throw 'Restore wrote through a receiving-vault snippets junction.'
    }

    $ancestorExternal = Join-Path $testRoot 'Ancestor Junction External'
    $ancestorSourceVault = Join-Path $ancestorExternal 'Source Vault'
    $ancestorTargetVault = Join-Path $ancestorExternal 'Target Vault'
    $ancestorAlias = Join-Path $testRoot 'Ancestor Junction Alias'
    Write-Utf8 -Path (Join-Path $ancestorSourceVault '.obsidian\app.json') -Value "{`"ancestor`":true}`n"
    Write-Utf8 -Path (Join-Path $ancestorTargetVault '.obsidian\app.json') -Value "{`"target`":`"old`"}`n"
    New-Item -ItemType Junction -Path $ancestorAlias -Target $ancestorExternal | Out-Null
    $exportAncestorRejected = $false
    try {
        & $export `
            -DestinationRoot (Join-Path $testRoot 'Ancestor Export') `
            -VaultRoot (Join-Path $ancestorAlias 'Source Vault') | Out-Null
    }
    catch {
        $exportAncestorRejected = $true
    }
    if (-not $exportAncestorRejected) {
        throw 'Exporter accepted a vault reached through a reparse-point ancestor.'
    }
    $restoreAncestorRejected = $false
    try {
        & $restore `
            -SourceRoot $exportRoot `
            -VaultRoot (Join-Path $ancestorAlias 'Target Vault') | Out-Null
    }
    catch {
        $restoreAncestorRejected = $true
    }
    if (-not $restoreAncestorRejected -or
        (Get-Content -LiteralPath (Join-Path $ancestorTargetVault '.obsidian\app.json') -Raw) -notmatch '"target":"old"') {
        throw 'Restore wrote through a reparse-point vault ancestor.'
    }

    $malformedPluginSource = Join-Path $testRoot 'Malformed Plugin Source'
    $malformedPluginTarget = Join-Path $testRoot 'Malformed Plugin Target'
    Write-Utf8 `
        -Path (Join-Path $malformedPluginSource 'community-plugins.json') `
        -Value "{`"calendar`":{`"settings`":`"embedded`"}}`n"
    Write-Utf8 `
        -Path (Join-Path $malformedPluginSource 'manifest.json') `
        -Value (([ordered]@{
            schemaVersion = 1
            files = @('community-plugins.json')
        } | ConvertTo-Json -Depth 5) + [Environment]::NewLine)
    Write-Utf8 `
        -Path (Join-Path $malformedPluginTarget '.obsidian\community-plugins.json') `
        -Value "[`"safe`"]`n"
    $malformedPluginSourceRejected = $false
    try {
        & $restore -SourceRoot $malformedPluginSource -VaultRoot $malformedPluginTarget | Out-Null
    }
    catch {
        $malformedPluginSourceRejected = $true
    }
    if (-not $malformedPluginSourceRejected -or
        (Get-Content -LiteralPath (Join-Path $malformedPluginTarget '.obsidian\community-plugins.json') -Raw).Trim() -ne '["safe"]') {
        throw 'Standalone restore accepted non-ID community plugin configuration.'
    }

    $manifestPath = Join-Path $exportRoot 'manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest.files = @($manifest.files) + '..\outside.txt'
    [System.IO.File]::WriteAllText(
        $manifestPath,
        ($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Utf8 -Path (Join-Path $targetVault '.obsidian\app.json') -Value "{`"target`":`"prevalidation`"}`n"
    $unsafeRejected = $false
    try {
        & $restore -SourceRoot $exportRoot -VaultRoot $targetVault | Out-Null
    }
    catch {
        $unsafeRejected = $true
    }
    if (-not $unsafeRejected) {
        throw 'Restore accepted a manifest path that escaped the portable configuration.'
    }
    if ((Get-Content -LiteralPath (Join-Path $targetVault '.obsidian\app.json') -Raw) -notmatch '"target":"prevalidation"') {
        throw 'Restore mutated the target before validating the complete manifest.'
    }

    $ambiguousRegistry = Join-Path $testRoot 'Roaming Profile\obsidian\ambiguous.json'
    Write-Utf8 -Path $ambiguousRegistry -Value (([ordered]@{
        vaults = [ordered]@{
            first = [ordered]@{ path = $sourceVault; open = $true }
            second = [ordered]@{ path = $targetVault; open = $true }
        }
    } | ConvertTo-Json -Depth 5) + [Environment]::NewLine)
    $ambiguousRejected = $false
    try {
        & $export `
            -DestinationRoot (Join-Path $testRoot 'Ambiguous Export') `
            -ObsidianRegistryPath $ambiguousRegistry | Out-Null
    }
    catch {
        $ambiguousRejected = $true
    }
    if (-not $ambiguousRejected) {
        throw 'Exporter accepted an Obsidian registry with multiple active vaults.'
    }

    $forbiddenRootRejected = $false
    try {
        & $export `
            -DestinationRoot (Join-Path $testRoot 'Forbidden Export') `
            -VaultRoot (Join-Path $sourceVault '26_Sensitive') | Out-Null
    }
    catch {
        $forbiddenRootRejected = $_.Exception.Message -match 'forbidden'
    }
    if (-not $forbiddenRootRejected) {
        throw 'Exporter did not explicitly reject a forbidden vault root before access.'
    }

    [pscustomobject]@{
        Result = 'PASS'
        ActiveVaultResolved = $true
        AmbiguousActiveVaultRejected = $true
        ForbiddenVaultRootRejected = $true
        AllowlistVerified = $true
        UnsafeFilesExcluded = $true
        ExportJunctionRejected = $true
        RestoreJunctionRejected = $true
        ExportAncestorJunctionRejected = $true
        RestoreAncestorJunctionRejected = $true
        MalformedPluginSourceRejected = $true
        OverlappingRestoreRejected = $true
        FullManifestPrevalidated = $true
        BackupVerified = $true
        TraversalRejected = $true
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
