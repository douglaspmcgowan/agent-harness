[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]+$')]
    [string]$Id,

    [Parameter(Mandatory = $true)]
    [string]$Incident,

    [Parameter(Mandatory = $true)]
    [ValidateSet('hypothesis', 'supported', 'reproduced')]
    [string]$RootCauseStatus,

    [Parameter(Mandatory = $true)]
    [ValidateSet('path', 'project', 'shared', 'platform', 'provider-model', 'human')]
    [string[]]$Scope,

    [Parameter(Mandatory = $true)]
    [ValidateSet('rule', 'skill', 'memory', 'verifier', 'hook', 'permission', 'test', 'brief', 'backlog')]
    [string[]]$Enforcement,

    [Parameter(Mandatory = $true)]
    [string[]]$Evidence,

    [string[]]$Surface = @(),
    [string[]]$Artifact = @(),
    [string]$Consequence = '',
    [string]$Verification = '',
    [string]$Owner = 'Douglas',
    [string]$ReviewTrigger = '',
    [ValidateSet('recorded', 'enforced', 'superseded', 'retired')]
    [string]$Status = 'recorded',
    [string]$Repository
)

$ErrorActionPreference = 'Stop'

function Assert-ValueFree([string]$Name, [string[]]$Values) {
    $blocked = '(?i)(password|passwd|secret|token|api[_-]?key|private[_-]?key)\s*[:=]\s*\S+'
    foreach ($value in $Values) {
        if ($value -match $blocked) {
            throw "$Name appears to contain a credential value. Record names and locations only."
        }
    }
}

Assert-ValueFree 'Incident' @($Incident)
Assert-ValueFree 'Evidence' $Evidence
Assert-ValueFree 'Consequence' @($Consequence)
Assert-ValueFree 'Verification' @($Verification)

if ($Repository) {
    $root = (Resolve-Path -LiteralPath $Repository).Path
    $logPath = Join-Path $root '.agents\feedback\FEEDBACK-LOG.md'
}
else {
    $agentsRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $logPath = Join-Path $agentsRoot 'feedback\FEEDBACK-LOG.md'
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('')
$lines.Add("## $Id")
$lines.Add('')
$lines.Add("timestamp: $((Get-Date).ToUniversalTime().ToString('o'))")
$lines.Add("incident: $($Incident.Replace("`r", ' ').Replace("`n", ' '))")
if ([string]::IsNullOrEmpty($Consequence)) {
    $lines.Add('consequence:')
}
else {
    $lines.Add("consequence: $($Consequence.Replace("`r", ' ').Replace("`n", ' '))")
}
$lines.Add("rootCauseStatus: $RootCauseStatus")
$lines.Add('scope:')
foreach ($value in $Scope) { $lines.Add("  - $value") }
$lines.Add('surfaces:')
foreach ($value in $Surface) { $lines.Add("  - $value") }
$lines.Add('enforcement:')
foreach ($value in $Enforcement) { $lines.Add("  - $value") }
$lines.Add('evidence:')
foreach ($value in $Evidence) { $lines.Add("  - $value") }
$lines.Add('artifacts:')
foreach ($value in $Artifact) { $lines.Add("  - $value") }
if ([string]::IsNullOrEmpty($Verification)) {
    $lines.Add('verification:')
}
else {
    $lines.Add("verification: $($Verification.Replace("`r", ' ').Replace("`n", ' '))")
}
$lines.Add("owner: $Owner")
$lines.Add("status: $Status")
if ([string]::IsNullOrEmpty($ReviewTrigger)) {
    $lines.Add('reviewTrigger:')
}
else {
    $lines.Add("reviewTrigger: $ReviewTrigger")
}

$parent = Split-Path $logPath -Parent
if ($PSCmdlet.ShouldProcess($logPath, 'Append value-free feedback record')) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    if (-not (Test-Path -LiteralPath $logPath)) {
        [System.IO.File]::WriteAllText(
            $logPath,
            "# Feedback log`r`n`r`nAppend-only, value-free correction records. Supersede or retire an entry by appending a new record that references its ID.`r`n",
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    [System.IO.File]::AppendAllText(
        $logPath,
        ($lines -join [Environment]::NewLine) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

[pscustomobject]@{
    Id = $Id
    Log = $logPath
    Scope = $Scope
    Enforcement = $Enforcement
}
