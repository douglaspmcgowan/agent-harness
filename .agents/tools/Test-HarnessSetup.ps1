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

& $manager -Action VerifyGlobal -HarnessRoot $HarnessRoot -HomeRoot $HomeRoot | Out-Null
& $manager -Action VerifyHumanGuide -HarnessRoot $HarnessRoot -HomeRoot $HomeRoot | Out-Null
& $manager -Action VerifyHooks -HarnessRoot $HarnessRoot -HomeRoot $HomeRoot | Out-Null

[pscustomobject]@{
    result = 'Harness setup verification passed through Manage-Harness.'
    harnessRoot = [System.IO.Path]::GetFullPath($HarnessRoot)
}
