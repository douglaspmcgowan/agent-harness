[CmdletBinding()]
param(
    [string]$Repository = (Get-Location).Path,
    [switch]$AllowCommandPlaceholders,
    [string]$HarnessRoot,
    [string]$HomeRoot = $env:USERPROFILE
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($HarnessRoot)) {
    $HarnessRoot = Split-Path $PSScriptRoot -Parent
}
& (Join-Path $PSScriptRoot 'Manage-Harness.ps1') `
    -Action VerifyProject `
    -HarnessRoot $HarnessRoot `
    -HomeRoot $HomeRoot `
    -Repository $Repository
