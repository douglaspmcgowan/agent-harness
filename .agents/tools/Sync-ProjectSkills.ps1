[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [string]$SkillsRoot = 'C:\Users\dougl\.agents\skills'
)

$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path -LiteralPath $Repository).Path
$sourceRoot = (Resolve-Path -LiteralPath $SkillsRoot).Path
$manifestPath = Join-Path $repoPath 'skills-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing skills manifest: $manifestPath"
}

function Get-TreeHash([string]$Root) {
    $rows = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
        Where-Object { $_.Name -ne '.projection.json' } |
        ForEach-Object {
            $relative = $_.FullName.Substring($Root.Length).TrimStart('\')
            "$relative`t$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"
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

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$bindings = @($manifest.bindings | Where-Object {
    $_.cloudRequired -eq $true -or $_.delivery -eq 'vendored'
})
$targetRoot = Join-Path $repoPath '.agents\skills'
if (-not (Test-Path -LiteralPath $targetRoot) -and $PSCmdlet.ShouldProcess($targetRoot, 'Create project skill directory')) {
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
}

$entries = [System.Collections.Generic.List[object]]::new()
foreach ($binding in $bindings) {
    $name = [string]$(if ($binding.name) { $binding.name } else { $binding.skill })
    if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Unsafe or missing skill name in manifest: $name"
    }
    $source = Join-Path $sourceRoot $name
    if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) {
        throw "Canonical skill is missing SKILL.md: $source"
    }
    $hash = Get-TreeHash $source
    $target = Join-Path $targetRoot $name
    $markerPath = Join-Path $target '.projection.json'

    if (Test-Path -LiteralPath $target) {
        if (-not (Test-Path -LiteralPath $markerPath)) {
            $entries.Add([ordered]@{ name = $name; source = $target; sha256 = (Get-TreeHash $target); status = 'project-owned' })
            continue
        }
        $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
        if ([string]$marker.name -ne $name -or [string]$marker.source -ne $source) {
            throw "Projection marker does not authorize replacement: $markerPath"
        }
        if ([string]$marker.sha256 -eq $hash) {
            $entries.Add([ordered]@{ name = $name; source = $source; sha256 = $hash; status = 'current' })
            continue
        }
    }

    if ($PSCmdlet.ShouldProcess($target, 'Project canonical skill into repository')) {
        $parent = Split-Path $target -Parent
        $temp = Join-Path $parent ('.' + $name + '.projection-' + [Guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $source -Destination $temp -Recurse
        $marker = [ordered]@{
            schemaVersion = 1
            name = $name
            source = $source
            sha256 = $hash
            generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        }
        [System.IO.File]::WriteAllText(
            (Join-Path $temp '.projection.json'),
            ($marker | ConvertTo-Json -Depth 4) + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
        if (Test-Path -LiteralPath $target) {
            $resolvedTarget = [System.IO.Path]::GetFullPath($target)
            $resolvedRoot = [System.IO.Path]::GetFullPath($targetRoot).TrimEnd('\') + '\'
            if (-not $resolvedTarget.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to replace a skill outside the project skill root: $resolvedTarget"
            }
            Remove-Item -LiteralPath $resolvedTarget -Recurse
        }
        Move-Item -LiteralPath $temp -Destination $target
    }
    $entries.Add([ordered]@{ name = $name; source = $source; sha256 = $hash; status = 'projected' })
}

$projection = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    entries = @($entries)
}
$projectionPath = Join-Path $repoPath 'skill-projection-manifest.json'
if ($PSCmdlet.ShouldProcess($projectionPath, 'Write project skill projection manifest')) {
    [System.IO.File]::WriteAllText(
        $projectionPath,
        ($projection | ConvertTo-Json -Depth 6) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

[pscustomobject]@{
    Repository = $repoPath
    Selected = $bindings.Count
    Projected = @($entries | Where-Object { $_.status -eq 'projected' }).Count
    Current = @($entries | Where-Object { $_.status -eq 'current' }).Count
}
