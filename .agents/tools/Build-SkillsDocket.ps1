[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$AuditJsonl,

    [string]$Outbox = 'C:\Users\dougl\Data\Projects\agent-harness\docket-outbox\skills-audit'
)

$ErrorActionPreference = 'Stop'

function Slug([string]$Value) {
    $slug = $Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    return $slug.Trim('-')
}

function Text([object]$Value) {
    if ($null -eq $Value) { return '' }
    if ($Value -is [System.Array]) { return (@($Value) -join '; ') }
    return [string]$Value
}

$records = foreach ($path in $AuditJsonl) {
    $resolved = (Resolve-Path -LiteralPath $path).Path
    foreach ($line in [System.IO.File]::ReadLines($resolved)) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $line | ConvertFrom-Json
        }
    }
}

$duplicatePaths = @($records | Group-Object path | Where-Object Count -gt 1)
if ($duplicatePaths.Count) {
    throw "Duplicate skill paths: $($duplicatePaths.Name -join ', ')"
}

$lockHandle = $null
if (-not $WhatIfPreference) {
    $lockParent = Split-Path $Outbox -Parent
    if (-not (Test-Path -LiteralPath $lockParent)) {
        New-Item -ItemType Directory -Path $lockParent -Force | Out-Null
    }
    $lockPath = "$Outbox.build.lock"
    try {
        $lockHandle = [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    }
    catch {
        throw "Another Skills Docket build owns the outbox lock: $lockPath"
    }
}

try {
    if (-not (Test-Path -LiteralPath $Outbox) -and $PSCmdlet.ShouldProcess($Outbox, 'Create Skills Audit Docket outbox')) {
        New-Item -ItemType Directory -Path $Outbox -Force | Out-Null
    }

    $written = 0
    $expected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($record in @($records | Sort-Object name)) {
    $name = [string]$record.name
    $displayName = if ($record.catalog_name) { [string]$record.catalog_name } else { $name }
    $severity = if ($record.severity) { [string]$record.severity } else { 'none' }
    $status = if ($record.portable_status) { [string]$record.portable_status } else { 'broken' }
    $actions = Text $record.recommended_actions
    $findings = @(
        if (Text $record.product_dependencies) { "Product dependencies: $(Text $record.product_dependencies)" }
        if (Text $record.model_dependencies) { "Model dependencies: $(Text $record.model_dependencies)" }
        if (Text $record.shell_mismatches) { "Shell mismatches: $(Text $record.shell_mismatches)" }
        if (Text $record.overlaps) { "Overlaps: $(Text $record.overlaps)" }
        if (Text $record.bloat_findings) { "Bloat: $(Text $record.bloat_findings)" }
        if (Text $record.unsafe_or_overwrite_findings) { "Write safety: $(Text $record.unsafe_or_overwrite_findings)" }
        if (Text $record.missing_resources) { "Missing resources: $(Text $record.missing_resources)" }
    )
    if (-not $findings.Count) { $findings = @('No material issue recorded in this audit pass.') }

    $stableBody = "$($record.path)|$displayName|$status|$severity|$actions|$($findings -join '|')"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($stableBody)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $hasher.ComputeHash($bytes)
    }
    finally {
        $hasher.Dispose()
    }
    $hashText = ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant().Substring(0, 12)
    $id = "skills-audit--$(Slug $displayName)--$hashText"

    $description = @(
        "Recommendation: $(if ($actions) { $actions } else { 'Keep under observation.' })"
        "Portability: $status. Severity: $severity."
        $findings
        "Evidence: $($record.path)"
    ) -join [Environment]::NewLine

    $card = [ordered]@{
        id = $id
        kind = 'review'
        title = "Skill: $displayName"
        description = $description
        options = @('Approve remediation', 'Keep as-is', 'Defer', 'Needs deeper review')
        project = 'Skills Audit'
        set = "$status-$severity"
        blocking = $false
        sensitive = $false
        source = [string]$record.path
    }

    $target = Join-Path $Outbox ("$id.json")
    [void]$expected.Add((Split-Path -Leaf $target))
    if ($PSCmdlet.ShouldProcess($target, 'Write Docket review card')) {
        $json = $card | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($target, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
        $written += 1
    }
    }

    $stale = @(
        Get-ChildItem -LiteralPath $Outbox -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Where-Object { -not $expected.Contains($_.Name) }
    )
    $archived = 0
    if ($stale.Count) {
        $parent = Split-Path $Outbox -Parent
        $leaf = Split-Path $Outbox -Leaf
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
        $archive = Join-Path $parent "_history\$leaf.$stamp"
        if ($PSCmdlet.ShouldProcess($archive, "Archive $($stale.Count) stale Docket cards")) {
            New-Item -ItemType Directory -Path $archive -Force | Out-Null
            foreach ($file in $stale) {
                Move-Item -LiteralPath $file.FullName -Destination (Join-Path $archive $file.Name)
                $archived += 1
            }
        }
    }

    [pscustomobject]@{
        Records = @($records).Count
        CardsWritten = $written
        StaleArchived = $archived
        Outbox = $Outbox
    }
}
finally {
    if ($lockHandle) {
        $lockHandle.Dispose()
    }
}
