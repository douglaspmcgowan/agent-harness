[CmdletBinding()]
param(
    [string]$ManifestPath = (Join-Path (Get-Location).Path 'data-manifest.yaml'),
    [string]$AdapterRoot,
    [string]$ProjectAdapterRoot,
    [string]$SchemaPath
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($AdapterRoot)) {
    $AdapterRoot = $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($SchemaPath)) {
    $SchemaPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\data-manifest.schema.v2.json'
}
if ([string]::IsNullOrWhiteSpace($ProjectAdapterRoot)) {
    $ProjectAdapterRoot = Join-Path (Split-Path ([System.IO.Path]::GetFullPath($ManifestPath)) -Parent) '.agents\data'
}

function ConvertFrom-ManifestScalar([string]$Text, [int]$LineNumber) {
    $value = $Text.Trim()
    if (-not $value) {
        throw "Manifest line $LineNumber has an empty value."
    }
    if ($value.StartsWith('"')) {
        if (-not $value.EndsWith('"') -or $value.Length -lt 2) {
            throw "Manifest line $LineNumber has an unterminated quoted value."
        }
        try {
            return ($value | ConvertFrom-Json)
        }
        catch {
            throw "Manifest line $LineNumber has an invalid quoted value."
        }
    }
    if ($value.StartsWith("'")) {
        if (-not $value.EndsWith("'") -or $value.Length -lt 2) {
            throw "Manifest line $LineNumber has an unterminated quoted value."
        }
        return $value.Substring(1, $value.Length - 2).Replace("''", "'")
    }
    $number = 0
    if ([int]::TryParse($value, [ref]$number)) {
        return $number
    }
    return $value
}

function ConvertFrom-DataManifestYaml([string]$Path) {
    $manifest = @{}
    $assets = [System.Collections.Generic.List[hashtable]]::new()
    $currentAsset = $null
    $assetsDeclared = $false
    $assetsInlineEmpty = $false
    $lineNumber = 0

    foreach ($line in Get-Content -LiteralPath $Path) {
        $lineNumber++
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) {
            continue
        }
        if ($line.Contains("`t")) {
            throw "Malformed manifest line ${lineNumber}: tabs are unsupported."
        }

        if ($line -match '^([a-z_][a-z0-9_]*):\s*(.*)$') {
            $key = $Matches[1]
            $raw = $Matches[2]
            if ($manifest.ContainsKey($key)) {
                throw "Duplicate manifest field '$key' on line $lineNumber."
            }
            if ($key -eq 'assets') {
                $assetsDeclared = $true
                if ($raw.Trim() -eq '[]') {
                    $assetsInlineEmpty = $true
                }
                elseif ($raw.Trim()) {
                    throw "Malformed manifest line ${lineNumber}: assets must be [] or a block list."
                }
                $manifest[$key] = $assets
            }
            else {
                $manifest[$key] = ConvertFrom-ManifestScalar $raw $lineNumber
            }
            $currentAsset = $null
            continue
        }

        if ($line -match '^  - ([a-z_][a-z0-9_]*):\s*(.*)$') {
            if (-not $assetsDeclared -or $assetsInlineEmpty) {
                throw "Malformed manifest line ${lineNumber}: asset entry appears outside an assets block."
            }
            $currentAsset = @{}
            $assets.Add($currentAsset)
            $key = $Matches[1]
            $currentAsset[$key] = ConvertFrom-ManifestScalar $Matches[2] $lineNumber
            continue
        }

        if ($line -match '^    ([a-z_][a-z0-9_]*):\s*(.*)$') {
            if ($null -eq $currentAsset) {
                throw "Malformed manifest line ${lineNumber}: asset field appears before an asset entry."
            }
            $key = $Matches[1]
            if ($currentAsset.ContainsKey($key)) {
                throw "Duplicate asset field '$key' on line $lineNumber."
            }
            $currentAsset[$key] = ConvertFrom-ManifestScalar $Matches[2] $lineNumber
            continue
        }

        throw "Malformed manifest line ${lineNumber}: $($line.Trim())"
    }

    if (-not $assetsDeclared) {
        throw 'Manifest is missing required field: assets'
    }
    return $manifest
}

function Test-NonEmptyField([hashtable]$Asset, [string]$Field, [string]$AssetLabel) {
    if (-not $Asset.ContainsKey($Field) -or
        $null -eq $Asset[$Field] -or
        [string]::IsNullOrWhiteSpace([string]$Asset[$Field])) {
        throw "Asset '$AssetLabel' is missing required field: $Field"
    }
}

function Test-SafeDestination([string]$Destination, [string]$AssetLabel) {
    if ([System.IO.Path]::IsPathRooted($Destination) -or
        $Destination -match '[:*?"<>|]' -or
        $Destination.StartsWith('~')) {
        throw "Asset '$AssetLabel' has unsafe local_destination '$Destination'."
    }

    $segments = @($Destination -split '[/\\]')
    if ($segments.Count -lt 2 -or
        $segments[0] -notin @('inputs', 'runtime', 'outputs', 'private') -or
        @($segments | Where-Object { -not $_ -or $_ -in @('.', '..') }).Count) {
        throw "Asset '$AssetLabel' has unsafe local_destination '$Destination'."
    }
    foreach ($segment in $segments) {
        if ($segment -notmatch '^[A-Za-z0-9._ -]+$') {
            throw "Asset '$AssetLabel' has unsafe local_destination '$Destination'."
        }
    }

    $syntheticRoot = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) 'manifest-data-root'))
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $syntheticRoot ($segments -join [System.IO.Path]::DirectorySeparatorChar)))
    $prefix = $syntheticRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Asset '$AssetLabel' has unsafe local_destination '$Destination'."
    }
}

function Assert-NoReparsePoint([string]$Path, [string]$AssetLabel) {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $current = [System.IO.Path]::GetPathRoot($fullPath)
    $relative = $fullPath.Substring($current.Length)
    foreach ($segment in @($relative -split '[/\\]' | Where-Object { $_ })) {
        $current = Join-Path $current $segment
        $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Adapter path for asset '$AssetLabel' contains a reparse point: $current"
        }
    }
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Data manifest is missing: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
    throw "Data manifest schema is missing: $SchemaPath"
}
if (-not (Test-Path -LiteralPath $AdapterRoot -PathType Container)) {
    throw "Adapter root is missing: $AdapterRoot"
}

$schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
if ([string]$schema.'x-adapter-path-policy' -ne 'reject-reparse-points') {
    throw "Data manifest schema does not require the reviewed adapter reparse-point policy: $SchemaPath"
}
$manifest = ConvertFrom-DataManifestYaml $ManifestPath

foreach ($field in @('version', 'project', 'data_root_env', 'assets')) {
    if (-not $manifest.ContainsKey($field)) {
        throw "Manifest is missing required field: $field"
    }
}

$allowedManifestFields = @($schema.properties.PSObject.Properties.Name)
foreach ($field in $manifest.Keys) {
    if ($field -notin $allowedManifestFields) {
        throw "Unsupported manifest field: $field"
    }
}

$version = $manifest.version
if ($version -eq 1) {
    if (@($manifest.assets).Count) {
        throw 'Populated data manifests require version 2.'
    }
}
elseif ($version -ne [int]$schema.properties.version.const) {
    throw "Unsupported manifest version: $version"
}

if ([string]$manifest.project -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    throw 'Manifest project is malformed.'
}
if ([string]$manifest.data_root_env -notmatch '^[A-Z_][A-Z0-9_]*$') {
    throw 'Manifest data_root_env is malformed.'
}

if ($version -eq 1) {
    Write-Output "Data manifest validation passed: $ManifestPath (legacy empty manifest)."
    exit 0
}

$assetSchema = $schema.properties.assets.items
$allowedAssetFields = @($assetSchema.properties.PSObject.Properties.Name)
$supportedClasses = @($assetSchema.properties.class.enum)
$recoveryClasses = @($schema.'x-recovery-classes')
$staleWriteClasses = @($schema.'x-stale-write-classes')
$regenerationClasses = @($schema.'x-regeneration-classes')
$staleWriteRules = @($assetSchema.properties.stale_write_rule.enum)
$assetIds = @{}

foreach ($asset in @($manifest.assets)) {
    $label = if ($asset.ContainsKey('id')) { [string]$asset.id } else { '<unknown>' }
    foreach ($field in @($assetSchema.required)) {
        Test-NonEmptyField $asset ([string]$field) $label
    }
    foreach ($field in $asset.Keys) {
        if ($field -notin $allowedAssetFields) {
            throw "Unsupported asset field '$field' on asset '$label'."
        }
    }
    if ($asset.id -notmatch '^[a-z0-9][a-z0-9._-]*$') {
        throw "Asset '$label' has malformed id."
    }
    if ($assetIds.ContainsKey([string]$asset.id)) {
        throw "Duplicate asset id: $($asset.id)"
    }
    $assetIds[[string]$asset.id] = $true
    if ([string]$asset.project -ne [string]$manifest.project) {
        throw "Asset '$label' project must match manifest project '$($manifest.project)'."
    }
    if ([string]$asset.class -notin $supportedClasses) {
        throw "Unsupported asset class '$($asset.class)' on asset '$label'."
    }

    Test-SafeDestination ([string]$asset.local_destination) $label

    $adapter = [string]$asset.adapter
    $adapterBase = $null
    $adapterRelative = $null
    if ($adapter -match '^[A-Za-z0-9][A-Za-z0-9._-]*\.ps1$') {
        $adapterBase = $AdapterRoot
        $adapterRelative = $adapter
    }
    elseif ($adapter -match '^\.agents[/\\]data[/\\](?<relative>.+\.ps1)$') {
        $adapterBase = $ProjectAdapterRoot
        $adapterRelative = [string]$Matches.relative
        $segments = @($adapterRelative -split '[/\\]')
        if (@($segments | Where-Object {
            -not $_ -or $_ -in @('.', '..') -or $_ -notmatch '^[A-Za-z0-9._-]+$'
        }).Count) {
            throw "Asset '$label' has malformed adapter declaration."
        }
    }
    else {
        throw "Asset '$label' has malformed adapter declaration."
    }

    $adapterBase = [System.IO.Path]::GetFullPath($adapterBase)
    $adapterPath = [System.IO.Path]::GetFullPath((Join-Path $adapterBase $adapterRelative))
    $adapterPrefix = $adapterBase.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $adapterPath.StartsWith($adapterPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $adapterPath)) {
        throw "Adapter '$adapter' for asset '$label' does not resolve to an installed reviewed implementation."
    }
    Assert-NoReparsePoint $adapterPath $label
    if (-not (Test-Path -LiteralPath $adapterPath -PathType Leaf)) {
        throw "Adapter '$adapter' for asset '$label' does not resolve to an installed reviewed implementation."
    }

    if ([string]$asset.class -in $recoveryClasses) {
        Test-NonEmptyField $asset 'recovery_rule' $label
    }
    $retentionFields = @('retention_daily', 'retention_weekly', 'retention_monthly')
    $declaredRetentionFields = @($retentionFields | Where-Object { $asset.ContainsKey($_) })
    if ($declaredRetentionFields.Count -notin @(0, 3)) {
        throw "Asset '$label' must declare all three retention fields or omit all three."
    }
    if ($declaredRetentionFields.Count -eq 3) {
        foreach ($field in $retentionFields) {
            $value = $asset[$field]
            if ($value -isnot [int] -or $value -lt 0) {
                throw "Asset '$label' has invalid $field; expected a nonnegative integer."
            }
        }
    }
    if ([string]$asset.class -in $staleWriteClasses) {
        Test-NonEmptyField $asset 'stale_write_rule' $label
        if ([string]$asset.stale_write_rule -notin $staleWriteRules) {
            throw "Unsupported stale_write_rule '$($asset.stale_write_rule)' on asset '$label'."
        }
    }
    if ([string]$asset.class -in $regenerationClasses) {
        Test-NonEmptyField $asset 'regeneration_rule' $label
    }
}

Write-Output "Data manifest validation passed: $ManifestPath ($(@($manifest.assets).Count) assets)."
