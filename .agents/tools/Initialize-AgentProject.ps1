[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$ProjectName,

    [string]$HarnessRoot,
    [string]$HomeRoot = $env:USERPROFILE,
    [switch]$IncludeProduct
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($HarnessRoot)) {
    $HarnessRoot = Split-Path $PSScriptRoot -Parent
}
& (Join-Path $PSScriptRoot 'Manage-Harness.ps1') `
    -Action EnsureProject `
    -HarnessRoot $HarnessRoot `
    -HomeRoot $HomeRoot `
    -Repository $Repository `
    -ProjectName $ProjectName `
    -IncludeProduct:$IncludeProduct `
    -WhatIf:$WhatIfPreference
