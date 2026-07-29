[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CanonicalRoot = 'C:\Users\dougl\.agents\skills',
    [string]$ClaudeRoot = 'C:\Users\dougl\.claude\skills',
    [string]$AdapterRegistry = 'C:\Users\dougl\.agents\CLAUDE-SKILL-ADAPTERS.json',
    [string[]]$Include,
    [switch]$IncludeSourceCommandAliases
)

$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path -LiteralPath $CanonicalRoot).Path
if (-not (Test-Path -LiteralPath $ClaudeRoot)) {
    New-Item -ItemType Directory -Path $ClaudeRoot -Force | Out-Null
}
$targetRoot = (Resolve-Path -LiteralPath $ClaudeRoot).Path
$adapterApprovals = @()
if (Test-Path -LiteralPath $AdapterRegistry) {
    $adapterApprovals = @((Get-Content -Raw -LiteralPath $AdapterRegistry | ConvertFrom-Json).adapters)
}

function Get-TreeHash([string]$Root) {
    $rows = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
        Where-Object { $_.Name -ne '.projection.json' } |
        ForEach-Object {
            $relative = $_.FullName.Substring($Root.Length).TrimStart('\')
            $fileHasher = [System.Security.Cryptography.SHA256]::Create()
            $stream = [System.IO.File]::OpenRead($_.FullName)
            try {
                $fileHash = ([BitConverter]::ToString($fileHasher.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
            }
            finally {
                $stream.Dispose()
                $fileHasher.Dispose()
            }
            "$relative`t$fileHash"
        } |
        Sort-Object
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($rows -join "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

$packages = Get-ChildItem -LiteralPath $sourceRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
    Where-Object { $IncludeSourceCommandAliases -or $_.Name -notlike 'source-command-*' }

if ($Include) {
    $selected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $Include) { [void]$selected.Add($name) }
    $packages = $packages | Where-Object { $selected.Contains($_.Name) }
    $missing = @($Include | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sourceRoot "$_\SKILL.md")) })
    if ($missing.Count) { throw "Requested canonical skills are missing: $($missing -join ', ')" }
}

$entries = [System.Collections.Generic.List[object]]::new()
foreach ($package in @($packages | Sort-Object Name)) {
    $name = $package.Name
    $source = $package.FullName
    $hash = Get-TreeHash $source
    $target = Join-Path $targetRoot $name
    $markerPath = Join-Path $target '.projection.json'

    if (Test-Path -LiteralPath $target) {
        if (-not (Test-Path -LiteralPath $markerPath)) {
            $targetHash = Get-TreeHash $target
            $approval = $adapterApprovals | Where-Object {
                $_.name -eq $name -and
                $_.sourceSha256 -eq $hash -and
                $_.targetSha256 -eq $targetHash
            }
            $status = if ($targetHash -eq $hash) {
                'unmanaged-current'
            }
            elseif ($approval) {
                'reviewed-adapter'
            }
            else {
                'unmanaged-different'
            }
            $entries.Add([ordered]@{
                name = $name
                source = $source
                sourceSha256 = $hash
                targetSha256 = $targetHash
                kind = 'adapter:claude'
                status = $status
            })
            continue
        }
        $marker = Get-Content -Raw -LiteralPath $markerPath | ConvertFrom-Json
        if ([string]$marker.name -ne $name -or [string]$marker.source -ne $source) {
            throw "Projection marker does not authorize replacement: $markerPath"
        }
        if ([string]$marker.sha256 -eq $hash) {
            $entries.Add([ordered]@{
                name = $name
                source = $source
                sourceSha256 = $hash
                kind = 'adapter:claude'
                status = 'current'
            })
            continue
        }
    }

    if ($PSCmdlet.ShouldProcess($target, 'Project canonical skill into Claude')) {
        $temp = Join-Path $targetRoot ('.' + $name + '.projection-' + [Guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $source -Destination $temp -Recurse
        $marker = [ordered]@{
            schemaVersion = 1
            name = $name
            source = $source
            sha256 = $hash
            kind = 'adapter:claude'
            generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        }
        [System.IO.File]::WriteAllText(
            (Join-Path $temp '.projection.json'),
            ($marker | ConvertTo-Json -Depth 5) + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
        if (Test-Path -LiteralPath $target) {
            $resolvedTarget = [System.IO.Path]::GetFullPath($target)
            $resolvedRoot = [System.IO.Path]::GetFullPath($targetRoot).TrimEnd('\') + '\'
            if (-not $resolvedTarget.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to replace a projection outside Claude's skill root: $resolvedTarget"
            }
            Remove-Item -LiteralPath $resolvedTarget -Recurse
        }
        Move-Item -LiteralPath $temp -Destination $target
    }
    $entries.Add([ordered]@{
        name = $name
        source = $source
        sourceSha256 = $hash
        kind = 'adapter:claude'
        status = 'projected'
    })
}

$manifest = [ordered]@{
    schemaVersion = 1
    policy = 'All canonical non-source-command skills; legacy source-command aliases remain in Claude commands.'
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    entries = @($entries)
}
$manifestPath = Join-Path (Split-Path $targetRoot -Parent) 'skill-projection-manifest.json'
if ($PSCmdlet.ShouldProcess($manifestPath, 'Write Claude skill projection manifest')) {
    [System.IO.File]::WriteAllText(
        $manifestPath,
        ($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

[pscustomobject]@{
    Canonical = @($packages).Count
    Projected = @($entries | Where-Object status -eq 'projected').Count
    Current = @($entries | Where-Object { $_.status -in @('current', 'unmanaged-current') }).Count
    ReviewedAdapters = @($entries | Where-Object status -eq 'reviewed-adapter').Count
    Conflicts = @($entries | Where-Object status -eq 'unmanaged-different').Count
    Manifest = $manifestPath
}
