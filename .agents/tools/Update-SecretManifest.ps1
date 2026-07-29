[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [string]$ProjectName,

    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$repoPath = (Resolve-Path -LiteralPath $Repository).Path
$jsonPath = Join-Path $repoPath 'secret-manifest.json'
$markdownPath = Join-Path $repoPath 'secret-manifest.md'
$examplePath = Join-Path $repoPath '.env.example'

if (-not (Test-Path -LiteralPath $jsonPath)) {
    throw "Missing canonical manifest: $jsonPath"
}

$manifest = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) {
    throw 'Unsupported secret-manifest schemaVersion.'
}

$allowedManifestFields = @('schemaVersion', 'project', 'variables')
foreach ($property in @($manifest.PSObject.Properties.Name)) {
    if ($property -notin $allowedManifestFields) {
        throw "Unsupported field in secret-manifest.json: $property"
    }
}
if ([string]$manifest.project -notmatch '^(?:<project-name>|[A-Za-z0-9][A-Za-z0-9._-]*)$') {
    throw 'secret-manifest.json has an invalid project identifier.'
}

$jsonNeedsWrite = $false
if ($ProjectName) {
    if ($ProjectName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Unsafe project name: $ProjectName"
    }
    if ([string]$manifest.project -ne $ProjectName) {
        $manifest.project = $ProjectName
        $jsonNeedsWrite = $true
    }
}

$declared = [ordered]@{}
$allowedVariableFields = @(
    'name', 'purpose', 'source', 'provider', 'trustBoundary',
    'owner', 'rotation', 'consumers', 'status'
)
foreach ($entry in @($manifest.variables)) {
    foreach ($property in @($entry.PSObject.Properties.Name)) {
        if ($property -notin $allowedVariableFields) {
            throw "Unsupported field '$property' on a secret-manifest variable. Secret values and credential material are forbidden."
        }
    }
    $name = [string]$entry.name
    if ($name -notmatch '^[A-Z][A-Z0-9_]*$') {
        throw "Invalid environment-variable name in secret-manifest.json: $name"
    }
    if ($declared.Contains($name)) {
        throw "Duplicate environment-variable name in secret-manifest.json: $name"
    }
    $declared[$name] = $entry
}

$discovered = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
if (Test-Path -LiteralPath $examplePath) {
    foreach ($line in [System.IO.File]::ReadLines($examplePath)) {
        if ($line -match '^\s*(?:export\s+)?([A-Z][A-Z0-9_]*)\s*=') {
            [void]$discovered.Add($Matches[1])
        }
    }
}

$missing = @($discovered | Where-Object { -not $declared.Contains($_) } | Sort-Object)
foreach ($name in $missing) {
    $declared[$name] = [pscustomobject][ordered]@{
        name = $name
        purpose = 'TODO: classify'
        source = 'runtime injection'
        provider = 'Bitwarden Secrets Manager or deployment platform'
        trustBoundary = 'development'
        owner = 'Douglas'
        rotation = 'on compromise, ownership change, or provider policy'
        consumers = @()
        status = 'needs-classification'
    }
    $jsonNeedsWrite = $true
}

$manifest.variables = @($declared.Values | Sort-Object name)

function Escape-Cell([object]$Value) {
    if ($null -eq $Value) { return '' }
    return ([string]$Value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

$rows = foreach ($entry in @($manifest.variables)) {
    $consumers = @($entry.consumers) -join ', '
    "| ``$(Escape-Cell $entry.name)`` | $(Escape-Cell $entry.purpose) | $(Escape-Cell $entry.provider) | $(Escape-Cell $entry.trustBoundary) | $(Escape-Cell $entry.owner) | $(Escape-Cell $entry.rotation) | $(Escape-Cell $consumers) | $(Escape-Cell $entry.status) |"
}

$markdown = @(
    '# Secret manifest'
    ''
    "Project: $($manifest.project)"
    ''
    'This generated view contains variable names and operating metadata only. Secret values, vault session keys, recovery keys, and access tokens are forbidden.'
    ''
    '| Variable | Purpose | Provider | Trust boundary | Owner | Rotation | Consumers | Status |'
    '|---|---|---|---|---|---|---|---|'
    $rows
    ''
    'Canonical source: `secret-manifest.json`'
    'Refresh: `C:\Users\dougl\.agents\tools\Update-SecretManifest.cmd -Repository <repo>`'
    ''
) -join [Environment]::NewLine

$json = $manifest | ConvertTo-Json -Depth 8
$json += [Environment]::NewLine

if ($Check) {
    if ($missing.Count) {
        throw "secret-manifest.json is missing $($missing.Count) name(s) declared in .env.example: $($missing -join ', ')"
    }
    if (-not (Test-Path -LiteralPath $markdownPath)) {
        throw "Missing generated manifest: $markdownPath"
    }
    $currentMarkdown = Get-Content -LiteralPath $markdownPath -Raw
    if ($currentMarkdown -ne $markdown) {
        throw 'secret-manifest.md is stale. Run Update-SecretManifest.cmd.'
    }
    Write-Output "Secret manifest check passed: $($manifest.variables.Count) variable name(s)."
    exit 0
}

if ($jsonNeedsWrite -and $PSCmdlet.ShouldProcess($jsonPath, 'Update value-free canonical secret manifest')) {
    [System.IO.File]::WriteAllText($jsonPath, $json, [System.Text.UTF8Encoding]::new($false))
}
if (
    (-not (Test-Path -LiteralPath $markdownPath) -or
        [System.IO.File]::ReadAllText($markdownPath) -cne $markdown) -and
    $PSCmdlet.ShouldProcess($markdownPath, 'Generate value-free secret manifest view')
) {
    [System.IO.File]::WriteAllText($markdownPath, $markdown, [System.Text.UTF8Encoding]::new($false))
}

[pscustomobject]@{
    Project = $manifest.project
    DeclaredNames = $manifest.variables.Count
    AddedNames = $missing.Count
    Canonical = $jsonPath
    Generated = $markdownPath
}
