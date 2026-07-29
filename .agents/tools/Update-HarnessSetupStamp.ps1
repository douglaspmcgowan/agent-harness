[CmdletBinding()]
param(
    [string]$HarnessRoot,
    [string]$HomeRoot = $env:USERPROFILE
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($HarnessRoot)) {
    $HarnessRoot = Split-Path $PSScriptRoot -Parent
}
$manager = Join-Path $PSScriptRoot 'Manage-Harness.ps1'
& $manager -Action Stamp -HarnessRoot $HarnessRoot -HomeRoot $HomeRoot
