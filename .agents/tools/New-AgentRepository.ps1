[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [string]$ProjectName
)

$ErrorActionPreference = 'Stop'
$fullPath = [System.IO.Path]::GetFullPath($Repository)
if (-not $ProjectName) {
    $ProjectName = Split-Path $fullPath -Leaf
}
if ($ProjectName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    throw "Project name is unsafe for bootstrap paths: $ProjectName"
}

if (-not (Test-Path -LiteralPath $fullPath)) {
    if ($PSCmdlet.ShouldProcess($fullPath, 'Create repository directory')) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $fullPath '.git'))) {
    if ($PSCmdlet.ShouldProcess($fullPath, 'Initialize Git repository')) {
        & git.exe -C $fullPath init
        if ($LASTEXITCODE -ne 0) {
            throw 'git init failed.'
        }
    }
}

& (Join-Path $PSScriptRoot 'Ensure-AgentProject.ps1') `
    -Repository $fullPath `
    -ProjectName $ProjectName `
    -WhatIf:$WhatIfPreference
