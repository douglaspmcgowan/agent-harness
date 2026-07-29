[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Root,

    [string]$RootList,

    [string]$Output
)

$ErrorActionPreference = 'Stop'

$candidates = @($Root | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($RootList) {
    $candidates += @($RootList -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
if (-not $candidates.Count) {
    throw 'Provide -Root from PowerShell or a semicolon-delimited -RootList.'
}

$files = foreach ($candidate in $candidates) {
    $resolved = (Resolve-Path -LiteralPath $candidate).Path
    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        if ((Split-Path -Leaf $resolved) -ne 'SKILL.md') {
            throw "Expected a SKILL.md file: $resolved"
        }
        Get-Item -LiteralPath $resolved
    }
    else {
        Get-ChildItem -LiteralPath $resolved -Recurse -Filter 'SKILL.md' -File
    }
}

$files = @($files | Sort-Object FullName -Unique)
$records = foreach ($file in $files) {
    $lines = [System.IO.File]::ReadAllLines($file.FullName)
    $raw = $lines -join "`n"
    $frontmatterOk = $lines.Count -ge 4 -and $lines[0] -eq '---'
    $name = ''
    $description = ''
    $frontmatterKeys = @()

    if ($frontmatterOk) {
        $closing = [Array]::IndexOf($lines, '---', 1)
        if ($closing -gt 1) {
            foreach ($line in $lines[1..($closing - 1)]) {
                if ($line -match '^([A-Za-z][A-Za-z0-9_-]*):') { $frontmatterKeys += $Matches[1] }
                if ($line -match '^name:\s*(.+?)\s*$') { $name = $Matches[1].Trim('"', "'") }
                if ($line -match '^description:\s*(.+?)\s*$') { $description = $Matches[1].Trim('"', "'") }
            }
            $frontmatterOk =
                [bool]$name -and
                [bool]$description -and
                @($frontmatterKeys | Sort-Object -Unique).Count -eq 2 -and
                $frontmatterKeys -contains 'name' -and
                $frontmatterKeys -contains 'description'
        }
        else {
            $frontmatterOk = $false
        }
    }

    $hardcoded = @()
    if ($raw -match '(?i)[A-Z]:\\Users\\|/Users/|/home/|~[\\/]\.?(?:Codex|claude|cursor)') {
        $hardcoded += 'machine-specific or product-home path signal'
    }

    $shell = @()
    if ($raw -match '(?m)^\s*(rm|mv|cp|cat|grep|chmod|source)\s') { $shell += 'POSIX command signal' }
    if ($raw -match '\s&&\s') { $shell += 'Bash-style command chaining signal' }

    $product = @()
    foreach ($token in @(
        'Claude', 'Codex', 'Cursor', 'MCP', 'Obsidian', 'Vercel',
        'WebSearch', 'WebFetch', 'AskUserQuestion', 'run_in_background'
    )) {
        if ($raw -match "(?i)\b$([regex]::Escape($token))\b") { $product += $token }
    }

    $model = @()
    foreach ($token in @('Haiku', 'Sonnet', 'Opus', 'GPT-4', 'GPT-5', 'Gemini')) {
        if ($raw -match "(?i)\b$([regex]::Escape($token))\b") { $model += $token }
    }

    [ordered]@{
        name = $name
        path = $file.FullName
        line_count = $lines.Count
        frontmatter_ok = $frontmatterOk
        description_length = $description.Length
        signals = [ordered]@{
            large_body = ($lines.Count -gt 500)
            long_description = ($description.Length -gt 300)
            product_tokens = $product
            model_tokens = $model
            hardcoded_paths = $hardcoded
            shell_mismatches = $shell
            write_terms = @('overwrite', 'Remove-Item', 'rm -rf') | Where-Object { $raw -match [regex]::Escape($_) }
        }
        semantic_review_required = $true
    }
}

$jsonLines = @($records | ForEach-Object { $_ | ConvertTo-Json -Depth 8 -Compress })
if ($Output) {
    $target = [System.IO.Path]::GetFullPath($Output)
    $parent = Split-Path -Parent $target
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllLines($target, $jsonLines, [System.Text.UTF8Encoding]::new($false))
}
else {
    $jsonLines
}

$summary = [pscustomobject]@{
    FilesDiscovered = $files.Count
    RecordsProduced = @($records).Count
    Output = $Output
}
Write-Information -MessageData $summary -InformationAction Continue
