[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$Name,
    [switch]$AllUnresolved,
    [Parameter(Mandatory = $true)]
    [string]$Reason,
    [string]$ProjectionManifest = 'C:\Users\dougl\.claude\skill-projection-manifest.json',
    [string]$Registry = 'C:\Users\dougl\.agents\CLAUDE-SKILL-ADAPTERS.json'
)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content -Raw -LiteralPath $ProjectionManifest | ConvertFrom-Json
if ($AllUnresolved) {
    $Name = @($manifest.entries | Where-Object status -eq 'unmanaged-different' | ForEach-Object name)
}
if (-not $Name.Count) {
    throw 'Specify -Name or -AllUnresolved.'
}
$existing = if (Test-Path -LiteralPath $Registry) {
    @((Get-Content -Raw -LiteralPath $Registry | ConvertFrom-Json).adapters)
}
else {
    @()
}

$selected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($value in $Name) { [void]$selected.Add($value) }
$entries = @($manifest.entries | Where-Object { $selected.Contains([string]$_.name) })
$missing = @($Name | Where-Object { $_ -notin @($entries.name) })
if ($missing.Count) { throw "Skills are absent from the projection manifest: $($missing -join ', ')" }

foreach ($entry in $entries) {
    if ($entry.status -ne 'unmanaged-different') {
        throw "Adapter approval requires an unresolved unmanaged difference: $($entry.name) is $($entry.status)"
    }
    if (-not $entry.sourceSha256 -or -not $entry.targetSha256) {
        throw "Adapter hashes are missing for $($entry.name)"
    }
}

$retained = @($existing | Where-Object { -not $selected.Contains([string]$_.name) })
$approvedAt = (Get-Date).ToUniversalTime().ToString('o')
$additions = foreach ($entry in $entries) {
    [ordered]@{
        name = [string]$entry.name
        kind = 'adapter:claude'
        source = [string]$entry.source
        sourceSha256 = [string]$entry.sourceSha256
        targetSha256 = [string]$entry.targetSha256
        reason = $Reason
        approvedAt = $approvedAt
        reviewTrigger = 'source or target hash changes'
    }
}
$document = [ordered]@{
    schemaVersion = 1
    purpose = 'Exact-hash approvals for intentional Claude skill adapters.'
    adapters = @($retained + $additions | Sort-Object name)
}

if ($PSCmdlet.ShouldProcess($Registry, 'Approve exact current Claude adapter hashes')) {
    if (Test-Path -LiteralPath $Registry) {
        $backupDir = 'C:\Users\dougl\Data\Projects\agent-harness\adapter-registry-backups'
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        $backup = Join-Path $backupDir ("CLAUDE-SKILL-ADAPTERS.$((Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')).json")
        Copy-Item -LiteralPath $Registry -Destination $backup
    }
    [System.IO.File]::WriteAllText(
        $Registry,
        ($document | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

[pscustomobject]@{
    Approved = $entries.Count
    Registry = $Registry
    ReviewTrigger = 'source or target hash changes'
}
