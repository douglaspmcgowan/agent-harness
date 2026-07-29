[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Repository,

    [string]$PrinciplesPath,
    [string]$BackupRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $env:LOCALAPPDATA 'AgentHarness\contract-backups'
}
if ($PrinciplesPath) {
    Write-Warning '-PrinciplesPath is retained for command compatibility; the canonical v3 template is owned by Manage-Harness.ps1.'
}

$manager = Join-Path $PSScriptRoot 'Manage-Harness.ps1'
if (-not (Test-Path -LiteralPath $manager -PathType Leaf)) {
    throw "Canonical harness manager is missing: $manager"
}
$harnessRoot = Split-Path $PSScriptRoot -Parent

foreach ($repo in $Repository) {
    $arguments = @{
        Action = 'EnsureProject'
        HarnessRoot = $harnessRoot
        HomeRoot = $BackupRoot
        Repository = $repo
    }
    if ($WhatIfPreference) {
        $arguments.DryRun = $true
    }
    & $manager @arguments
}
