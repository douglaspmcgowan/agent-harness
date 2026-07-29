[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [switch]$HookOnly
)

$ErrorActionPreference = 'Stop'

$repoPath = (Resolve-Path -LiteralPath $Repository).Path
$git = Get-Command git.exe -ErrorAction Stop
$gitleaks = Get-Command gitleaks.exe -ErrorAction SilentlyContinue
if (-not $gitleaks) {
    throw 'Gitleaks is unavailable from PATH.'
}
$gitleaksPath = if ($gitleaks -is [System.Management.Automation.ApplicationInfo]) {
    $gitleaks.Source
}
else {
    $gitleaks.FullName
}
if (-not $gitleaksPath -or -not (Test-Path -LiteralPath $gitleaksPath)) {
    throw 'Gitleaks command resolved without an executable path.'
}

& $git.Source -C $repoPath rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    throw "This path is outside a Git worktree: $repoPath"
}

$templateRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\gitleaks'
$hookSource = Join-Path $templateRoot 'pre-commit'
$configSource = Join-Path $templateRoot '.gitleaks.toml'
$workflowSource = Join-Path $templateRoot 'gitleaks.yml'

$hookRootRaw = (& $git.Source -C $repoPath rev-parse --git-path hooks).Trim()
if ([System.IO.Path]::IsPathRooted($hookRootRaw)) {
    $hookRoot = $hookRootRaw
}
else {
    $hookRoot = [System.IO.Path]::GetFullPath((Join-Path $repoPath $hookRootRaw))
}

$hookTarget = Join-Path $hookRoot 'pre-commit'
New-Item -ItemType Directory -Path $hookRoot -Force | Out-Null

if (Test-Path -LiteralPath $hookTarget) {
    $sourceHash = (Get-FileHash -LiteralPath $hookSource -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $hookTarget -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        throw "An existing pre-commit hook requires manual integration: $hookTarget"
    }
}
elseif ($PSCmdlet.ShouldProcess($hookTarget, 'Install Gitleaks pre-commit hook')) {
    Copy-Item -LiteralPath $hookSource -Destination $hookTarget
}

if (-not $HookOnly) {
    $configTarget = Join-Path $repoPath '.gitleaks.toml'
    $workflowTarget = Join-Path $repoPath '.github\workflows\gitleaks.yml'

    if (-not (Test-Path -LiteralPath $configTarget) -and $PSCmdlet.ShouldProcess($configTarget, 'Install Gitleaks project configuration')) {
        Copy-Item -LiteralPath $configSource -Destination $configTarget
    }

    if (-not (Test-Path -LiteralPath $workflowTarget) -and $PSCmdlet.ShouldProcess($workflowTarget, 'Install Gitleaks GitHub Actions workflow')) {
        New-Item -ItemType Directory -Path (Split-Path $workflowTarget -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $workflowSource -Destination $workflowTarget
    }
}

& $gitleaksPath git --redact --no-banner $repoPath
if ($LASTEXITCODE -ne 0) {
    throw 'Gitleaks found a potential secret. Review the redacted findings before continuing.'
}

[pscustomobject]@{
    Repository = $repoPath
    Hook = $hookTarget
    ProjectFiles = -not $HookOnly
    Scan = 'passed'
}
