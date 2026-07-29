[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository
)

$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath($Repository)
$failures = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $repo -PathType Container)) {
    throw "Repository directory does not exist: $repo"
}

$requiredFiles = @(
    'AGENTS.md',
    'CLIENT.md',
    'DELIVERABLES.md',
    'SOURCES.md',
    'CURRENT-TASK.md',
    'WORK_QUEUE.md',
    'STATUS.md',
    'LOG.md',
    'VERIFY.md',
    'data-manifest.yaml',
    'secret-manifest.json',
    'skills-manifest.json'
)

foreach ($relative in $requiredFiles) {
    $path = Join-Path $repo $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing required file: $relative")
    }
}

$headingContract = @{
    'CLIENT.md' = @(
        '# Client profile',
        '## Identity',
        '## Business',
        '## Stakeholders and decisions',
        '## Current digital estate',
        '## Brand',
        '## Constraints and risks',
        '## AI context',
        '## Evidence status'
    )
    'DELIVERABLES.md' = @(
        '# Deliverables',
        '## Delivery rules',
        '## Register',
        '## Detail',
        '## Change record'
    )
    'SOURCES.md' = @(
        '# Sources and assets',
        '## Source ledger',
        '## Asset ledger',
        '## Decisions',
        '## Provenance gaps'
    )
}

foreach ($relative in $headingContract.Keys) {
    $path = Join-Path $repo $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        continue
    }
    $content = Get-Content -LiteralPath $path -Raw
    foreach ($heading in $headingContract[$relative]) {
        if ($content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $failures.Add("$relative lacks heading: $heading")
        }
    }
}

$deliverablesPath = Join-Path $repo 'DELIVERABLES.md'
if (Test-Path -LiteralPath $deliverablesPath -PathType Leaf) {
    $deliverables = Get-Content -LiteralPath $deliverablesPath -Raw
    if ($deliverables -notmatch '\bDEL-\d{3}\b') {
        $failures.Add('DELIVERABLES.md has no stable DEL-### identifier.')
    }
    if ($deliverables -notmatch '\b(Requested|Proposed|Approved|Active|Blocked|In review|Verified|Delivered|Deferred|Cancelled)\b') {
        $failures.Add('DELIVERABLES.md has no recognized delivery state.')
    }
}

$sourcesPath = Join-Path $repo 'SOURCES.md'
if (Test-Path -LiteralPath $sourcesPath -PathType Leaf) {
    $sources = Get-Content -LiteralPath $sourcesPath -Raw
    if ($sources -notmatch '\b(MSG|FILE|WEB|DEC|OBS)-\d{3}\b') {
        $failures.Add('SOURCES.md has no stable source identifier.')
    }
}

$trackedTextFiles = @()
if (Test-Path -LiteralPath (Join-Path $repo '.git')) {
    $trackedTextFiles = & git.exe -C $repo ls-files '*.md' '*.json' '*.yaml' '*.yml' '*.txt' '*.env*'
}
foreach ($relative in $trackedTextFiles) {
    $path = Join-Path $repo $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        continue
    }
    $content = Get-Content -LiteralPath $path -Raw
    if ($content -match '(?im)^\s*(password|api[_ -]?key|access[_ -]?token|refresh[_ -]?token)\s*[:=]\s*\S+') {
        $failures.Add("Potential credential value in tracked file: $relative")
    }
}

if ($failures.Count -gt 0) {
    Write-Output 'Client project validation failed:'
    $failures | ForEach-Object { Write-Output " - $_" }
    exit 1
}

Write-Output "Client project validation passed: $repo"
