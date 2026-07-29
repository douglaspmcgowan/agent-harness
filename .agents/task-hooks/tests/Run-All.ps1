[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

node (Join-Path $PSScriptRoot 'portable-legacy-modules.test.js')
if ($LASTEXITCODE -ne 0) { throw 'portable-legacy-modules.test.js failed' }

node (Join-Path $PSScriptRoot 'security-dispatch.test.js')
if ($LASTEXITCODE -ne 0) { throw 'security-dispatch.test.js failed' }

node (Join-Path $PSScriptRoot 'task-state-dispatch.test.js')
if ($LASTEXITCODE -ne 0) { throw 'task-state-dispatch.test.js failed' }

node (Join-Path $PSScriptRoot 'continue-dispatch.test.js')
if ($LASTEXITCODE -ne 0) { throw 'continue-dispatch.test.js failed' }

node (Join-Path $PSScriptRoot 'config-contract.test.js')
if ($LASTEXITCODE -ne 0) { throw 'config-contract.test.js failed' }

node (Join-Path $PSScriptRoot 'notifications.test.js')
if ($LASTEXITCODE -ne 0) { throw 'notifications.test.js failed' }

& (Join-Path $PSScriptRoot 'Migrate-TaskState.Tests.ps1')

$expected = @(
    'hooks\security-dispatch.js',
    'hooks\task-state-dispatch.js',
    'hooks\continue-dispatch.js'
)
$actual = Get-ChildItem -LiteralPath (Join-Path $root 'hooks') -File -Filter '*-dispatch.js' |
    ForEach-Object { 'hooks\' + $_.Name }
if (Compare-Object $expected $actual) {
    throw 'The staged architecture must expose exactly three *-dispatch.js executables.'
}

Write-Output 'All staged task/hook tests passed.'
