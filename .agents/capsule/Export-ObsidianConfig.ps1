[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DestinationRoot,
    [string]$VaultRoot,
    [string]$ObsidianRegistryPath = (Join-Path $env:APPDATA 'obsidian\obsidian.json')
)

$ErrorActionPreference = 'Stop'
$portableRootFiles = @(
    'app.json',
    'appearance.json',
    'core-plugins.json',
    'hotkeys.json',
    'graph.json',
    'types.json'
)

function Assert-AllowedVaultRoot {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Obsidian vault root is empty.'
    }
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $segments = $full -split '\\'
    if ($segments -contains 'AI Reference' -or $segments -contains '26_Sensitive') {
        throw "Obsidian vault root is inside a forbidden path: $full"
    }
    foreach ($forbidden in @(
        'G:\My Drive\Actual Documents\Identity',
        '40_Reference\AI Reference.md',
        '31_Business\Other People Reference.md'
    )) {
        if ([string]::Equals($full, $forbidden, [StringComparison]::OrdinalIgnoreCase) -or
            $full.EndsWith('\' + $forbidden, [StringComparison]::OrdinalIgnoreCase) -or
            $full.StartsWith($forbidden.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Obsidian vault root is inside a forbidden path: $full"
        }
    }
    return $full
}

function Assert-NotReparsePoint {
    param([string]$Path, [string]$Label)

    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label must not be a reparse point: $Path"
    }
}

function Assert-NoReparseAncestors {
    param([string]$Path, [string]$Label)

    $full = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($full)
    $current = $pathRoot
    if (Test-Path -LiteralPath $current) {
        Assert-NotReparsePoint -Path $current -Label $Label
    }
    $relative = $full.Substring($pathRoot.Length).Trim('\')
    foreach ($segment in @($relative -split '\\' | Where-Object { $_ })) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        Assert-NotReparsePoint -Path $current -Label $Label
    }
}

function Resolve-ActiveObsidianVault {
    param([string]$RegistryPath)

    if (-not (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) {
        throw "Obsidian vault registry is unavailable: $RegistryPath"
    }
    $registry = Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $active = @($registry.vaults.PSObject.Properties |
        ForEach-Object { $_.Value } |
        Where-Object { $_.open -eq $true })
    if ($active.Count -ne 1) {
        throw "Obsidian must have exactly one active vault; found $($active.Count)."
    }
    $resolved = Assert-AllowedVaultRoot -Path ([string]$active[0].path)
    Assert-NoReparseAncestors -Path $resolved -Label 'Active Obsidian vault path'
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "The active Obsidian vault is unavailable: $resolved"
    }
    return $resolved
}

if (-not $VaultRoot) {
    $VaultRoot = Resolve-ActiveObsidianVault -RegistryPath $ObsidianRegistryPath
}
else {
    $VaultRoot = Assert-AllowedVaultRoot -Path $VaultRoot
    Assert-NoReparseAncestors -Path $VaultRoot -Label 'Obsidian vault path'
}

$sourceConfig = Join-Path $VaultRoot '.obsidian'
if (-not (Test-Path -LiteralPath $sourceConfig -PathType Container)) {
    throw "The active vault has no .obsidian configuration folder: $VaultRoot"
}
Assert-NotReparsePoint -Path $sourceConfig -Label 'Active vault configuration folder'
$DestinationRoot = [System.IO.Path]::GetFullPath($DestinationRoot)
Assert-NoReparseAncestors -Path $DestinationRoot -Label 'Obsidian export destination path'
$sourceConfigFull = [System.IO.Path]::GetFullPath($sourceConfig).TrimEnd('\')
if ([string]::Equals($DestinationRoot.TrimEnd('\'), $sourceConfigFull, [StringComparison]::OrdinalIgnoreCase) -or
    $DestinationRoot.StartsWith($sourceConfigFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Obsidian export destination must be outside the active vault configuration.'
}
if (Test-Path -LiteralPath $DestinationRoot) {
    if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) {
        throw "Obsidian export destination must be a directory: $DestinationRoot"
    }
    if (@(Get-ChildItem -LiteralPath $DestinationRoot -Force).Count -ne 0) {
        throw "Obsidian export destination must be empty: $DestinationRoot"
    }
    Assert-NotReparsePoint -Path $DestinationRoot -Label 'Obsidian export destination'
}
else {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}

foreach ($name in $portableRootFiles) {
    $source = Join-Path $sourceConfig $name
    if (Test-Path -LiteralPath $source -PathType Leaf) {
        Assert-NotReparsePoint -Path $source -Label 'Portable Obsidian configuration file'
        Copy-Item -LiteralPath $source -Destination (Join-Path $DestinationRoot $name)
    }
}

$pluginList = Join-Path $sourceConfig 'community-plugins.json'
if (Test-Path -LiteralPath $pluginList -PathType Leaf) {
    Assert-NotReparsePoint -Path $pluginList -Label 'Community plugin ID list'
    $decodedPluginIds = Get-Content -LiteralPath $pluginList -Raw -Encoding UTF8 | ConvertFrom-Json
    $pluginIds = @($decodedPluginIds)
    foreach ($pluginId in $pluginIds) {
        if ($pluginId -isnot [string] -or
            [string]::IsNullOrWhiteSpace([string]$pluginId) -or
            [string]$pluginId -notmatch '^[A-Za-z0-9._-]+$') {
            throw 'community-plugins.json must contain only plugin ID strings.'
        }
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $DestinationRoot 'community-plugins.json'),
        (ConvertTo-Json -InputObject $pluginIds -Depth 3) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$snippetsRoot = Join-Path $sourceConfig 'snippets'
if (Test-Path -LiteralPath $snippetsRoot -PathType Container) {
    Assert-NotReparsePoint -Path $snippetsRoot -Label 'Obsidian snippets folder'
    foreach ($snippet in @(Get-ChildItem -LiteralPath $snippetsRoot -File -Filter '*.css' -Force)) {
        Assert-NotReparsePoint -Path $snippet.FullName -Label 'Obsidian snippet'
        $destination = Join-Path $DestinationRoot ('snippets\' + $snippet.Name)
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $snippet.FullName -Destination $destination
    }
}

$themesRoot = Join-Path $sourceConfig 'themes'
if (Test-Path -LiteralPath $themesRoot -PathType Container) {
    Assert-NotReparsePoint -Path $themesRoot -Label 'Obsidian themes folder'
    foreach ($theme in @(Get-ChildItem -LiteralPath $themesRoot -Directory -Force)) {
        Assert-NotReparsePoint -Path $theme.FullName -Label 'Obsidian theme folder'
        foreach ($name in @('manifest.json', 'theme.css')) {
            $source = Join-Path $theme.FullName $name
            if (Test-Path -LiteralPath $source -PathType Leaf) {
                Assert-NotReparsePoint -Path $source -Label 'Obsidian theme file'
                $destination = Join-Path $DestinationRoot (Join-Path (Join-Path 'themes' $theme.Name) $name)
                New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
                Copy-Item -LiteralPath $source -Destination $destination
            }
        }
    }
}

$files = @(Get-ChildItem -LiteralPath $DestinationRoot -File -Recurse -Force |
    Sort-Object FullName |
    ForEach-Object { $_.FullName.Substring($DestinationRoot.Length).TrimStart('\').Replace('\', '/') })
[System.IO.File]::WriteAllText(
    (Join-Path $DestinationRoot 'manifest.json'),
    (([ordered]@{
        schemaVersion = 1
        exportedAt = (Get-Date).ToUniversalTime().ToString('o')
        files = $files
    }) | ConvertTo-Json -Depth 5) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{
    Result = 'PASS'
    VaultRoot = $VaultRoot
    DestinationRoot = $DestinationRoot
    Files = $files.Count
}
