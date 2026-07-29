[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [string]$VaultRoot,
    [string]$ObsidianRegistryPath = (Join-Path $env:APPDATA 'obsidian\obsidian.json'),
    [string]$BackupRoot
)

$ErrorActionPreference = 'Stop'
$portableRootFiles = @(
    'app.json',
    'appearance.json',
    'core-plugins.json',
    'hotkeys.json',
    'graph.json',
    'types.json',
    'community-plugins.json'
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

function Test-PortableRelativePath {
    param([string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        (($RelativePath -split '[\\/]') -contains '..')) {
        return $false
    }
    $normalized = $RelativePath.Replace('/', '\')
    if ($normalized -in $portableRootFiles) {
        return $true
    }
    if ($normalized -match '^snippets\\[^\\]+\.css$') {
        return $true
    }
    return $normalized -match '^themes\\[^\\]+\\(manifest\.json|theme\.css)$'
}

function Assert-PlainContainedPath {
    param(
        [string]$Root,
        [string]$Path,
        [string]$Label
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not [string]::Equals($pathFull, $rootFull, [StringComparison]::OrdinalIgnoreCase) -and
        -not $pathFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label escaped its root: $pathFull"
    }
    $current = $rootFull
    if (Test-Path -LiteralPath $current) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse point: $current"
        }
    }
    $relative = $pathFull.Substring($rootFull.Length).TrimStart('\')
    foreach ($segment in @($relative -split '\\' | Where-Object { $_ })) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse point: $current"
        }
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

function Enter-TargetLock {
    param([string]$Target)

    $lockDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'AgentHarness-ObsidianConfigLocks'
    New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
    $lockDirectoryItem = Get-Item -LiteralPath $lockDirectory -Force
    if (($lockDirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Obsidian restore lock directory must not be a reparse point: $lockDirectory"
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
            throw "Obsidian restore lock must not be a reparse point: $lockPath"
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
        throw "Another Obsidian configuration restore is active for $normalized"
    }
}

$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
Assert-NoReparseAncestors -Path $SourceRoot -Label 'Portable Obsidian configuration path'
if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "Portable Obsidian configuration is unavailable: $SourceRoot"
}
Assert-PlainContainedPath -Root $SourceRoot -Path $SourceRoot -Label 'Portable Obsidian configuration'
$manifestPath = Join-Path $SourceRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Portable Obsidian configuration manifest is unavailable: $manifestPath"
}
Assert-PlainContainedPath -Root $SourceRoot -Path $manifestPath -Label 'Portable Obsidian configuration manifest'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$manifest.schemaVersion -ne 1) {
    throw "Unsupported portable Obsidian configuration schema: $($manifest.schemaVersion)"
}

# Validate every manifest entry and source path before the receiving vault is changed.
$validated = [System.Collections.Generic.List[object]]::new()
$seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($manifestFile in @($manifest.files)) {
    $relative = [string]$manifestFile
    if (-not (Test-PortableRelativePath -RelativePath $relative)) {
        throw "Portable Obsidian configuration manifest contains an unsafe path: $relative"
    }
    $normalized = $relative.Replace('/', '\')
    if (-not $seen.Add($normalized)) {
        throw "Portable Obsidian configuration manifest contains a duplicate path: $relative"
    }
    $source = [System.IO.Path]::GetFullPath((Join-Path $SourceRoot $normalized))
    Assert-PlainContainedPath -Root $SourceRoot -Path $source -Label 'Portable Obsidian configuration file'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Portable Obsidian configuration file is unavailable: $relative"
    }
    if ([string]::Equals(
        $normalized,
        'community-plugins.json',
        [StringComparison]::OrdinalIgnoreCase
    )) {
        $pluginIdsRaw = Get-Content -LiteralPath $source -Raw -Encoding UTF8
        if (-not $pluginIdsRaw.Trim().StartsWith('[') -or
            -not $pluginIdsRaw.Trim().EndsWith(']')) {
            throw 'Portable community plugin configuration must be a JSON array of IDs.'
        }
        $decodedPluginIds = $pluginIdsRaw | ConvertFrom-Json
        foreach ($pluginId in @($decodedPluginIds)) {
            if ($pluginId -isnot [string] -or
                [string]::IsNullOrWhiteSpace([string]$pluginId) -or
                [string]$pluginId -notmatch '^[A-Za-z0-9._-]+$') {
                throw 'Portable community plugin configuration contains a non-ID value.'
            }
        }
    }
    $validated.Add([pscustomobject]@{
        Relative = $normalized
        Source = $source
    })
}

if (-not $VaultRoot) {
    $VaultRoot = Resolve-ActiveObsidianVault -RegistryPath $ObsidianRegistryPath
}
else {
    $VaultRoot = Assert-AllowedVaultRoot -Path $VaultRoot
}
Assert-NoReparseAncestors -Path $VaultRoot -Label 'Receiving Obsidian vault path'
$targetConfig = Join-Path $VaultRoot '.obsidian'
$restoreLock = Enter-TargetLock -Target $targetConfig
try {
if (-not (Test-Path -LiteralPath $VaultRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $VaultRoot -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $targetConfig)) {
    New-Item -ItemType Directory -Path $targetConfig -Force | Out-Null
}
Assert-PlainContainedPath -Root $targetConfig -Path $targetConfig -Label 'Receiving Obsidian configuration'

if (-not $BackupRoot) {
    $BackupRoot = Join-Path $VaultRoot (
        '.obsidian-backups\' +
        (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss') +
        '_' +
        [Guid]::NewGuid().ToString('N')
    )
}
$BackupRoot = [System.IO.Path]::GetFullPath($BackupRoot)
Assert-NoReparseAncestors -Path $BackupRoot -Label 'Obsidian configuration backup path'

foreach ($entry in $validated) {
    $destination = Join-Path $targetConfig $entry.Relative
    $destinationParent = Split-Path -Parent $destination
    Assert-PlainContainedPath `
        -Root $targetConfig `
        -Path $destinationParent `
        -Label 'Receiving Obsidian configuration path'
    if ((Test-Path -LiteralPath $destinationParent) -and
        -not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
        throw "Receiving Obsidian configuration parent is not a directory: $destinationParent"
    }
    if ((Test-Path -LiteralPath $destination) -and
        -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        throw "Receiving Obsidian configuration target is not a file: $destination"
    }
    Add-Member -InputObject $entry -NotePropertyName Destination -NotePropertyValue $destination
}

$completed = [System.Collections.Generic.List[object]]::new()
try {
    foreach ($entry in $validated) {
        $destinationParent = Split-Path -Parent $entry.Destination
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        Assert-PlainContainedPath `
            -Root $targetConfig `
            -Path $destinationParent `
            -Label 'Receiving Obsidian configuration path'

        $existed = Test-Path -LiteralPath $entry.Destination -PathType Leaf
        $backup = $null
        if ($existed) {
            Assert-PlainContainedPath `
                -Root $targetConfig `
                -Path $entry.Destination `
                -Label 'Receiving Obsidian configuration file'
            $backup = Join-Path $BackupRoot $entry.Relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
            Copy-Item -LiteralPath $entry.Destination -Destination $backup
        }
        $transaction = [pscustomobject]@{
            Destination = $entry.Destination
            Existed = $existed
            Backup = $backup
        }
        $completed.Add($transaction)

        $temporary = Join-Path $destinationParent ('.' + [Guid]::NewGuid().ToString('N') + '.tmp')
        try {
            Copy-Item -LiteralPath $entry.Source -Destination $temporary
            Move-Item -LiteralPath $temporary -Destination $entry.Destination -Force
        }
        finally {
            if (Test-Path -LiteralPath $temporary) {
                Remove-Item -LiteralPath $temporary -Force
            }
        }
    }
}
catch {
    for ($index = $completed.Count - 1; $index -ge 0; $index--) {
        $transaction = $completed[$index]
        if ($transaction.Existed -and
            $transaction.Backup -and
            (Test-Path -LiteralPath $transaction.Backup -PathType Leaf)) {
            Copy-Item -LiteralPath $transaction.Backup -Destination $transaction.Destination -Force
        }
        elseif (-not $transaction.Existed -and
            (Test-Path -LiteralPath $transaction.Destination -PathType Leaf)) {
            Remove-Item -LiteralPath $transaction.Destination -Force
        }
    }
    throw
}

[pscustomobject]@{
    Result = 'PASS'
    VaultRoot = $VaultRoot
    SourceRoot = $SourceRoot
    BackupRoot = $BackupRoot
    RestoredFiles = $validated.Count
    BackedUpFiles = @($completed | Where-Object Existed).Count
}
}
finally {
    $restoreLock.Dispose()
}
