[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Repository = (Get-Location).Path,
    [string]$ProjectName,
    [string]$HarnessRoot,
    [string]$HomeRoot = $env:USERPROFILE,
    [switch]$IncludeProduct
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($HarnessRoot)) {
    $HarnessRoot = Split-Path $PSScriptRoot -Parent
}
$arguments = @{
    Action = 'EnsureProject'
    HarnessRoot = $HarnessRoot
    HomeRoot = $HomeRoot
    Repository = $Repository
    IncludeProduct = $IncludeProduct
}
if ($ProjectName) { $arguments.ProjectName = $ProjectName }
& (Join-Path $PSScriptRoot 'Manage-Harness.ps1') @arguments -WhatIf:$WhatIfPreference
