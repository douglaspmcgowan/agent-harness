[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'Enable-Gitleaks.ps1'
$hookTemplate = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\gitleaks\pre-commit'
$testRoot = Join-Path $env:TEMP ('enable-gitleaks-test-' + [guid]::NewGuid().ToString('N'))

try {
    $hookTemplateContent = [System.IO.File]::ReadAllText($hookTemplate)
    if ($hookTemplateContent -match '(?i)(?:/c/|[A-Z]:\\)Users\\?/[A-Za-z0-9._-]+') {
        throw 'The pre-commit template contains a machine-specific user-profile path.'
    }

    $freshRepo = Join-Path $testRoot 'fresh'
    New-Item -ItemType Directory -Path $freshRepo -Force | Out-Null
    & git.exe -C $freshRepo init --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to initialize the disposable test repository.'
    }
    $freshHook = Join-Path $freshRepo '.git\hooks\pre-commit'
    if (Test-Path -LiteralPath $freshHook) {
        Remove-Item -LiteralPath $freshHook -Force
    }
    & $tool -Repository $freshRepo | Out-Null

    $required = @(
        (Join-Path $freshRepo '.gitleaks.toml'),
        (Join-Path $freshRepo '.github\workflows\gitleaks.yml'),
        (Join-Path $freshRepo '.git\hooks\pre-commit')
    )
    foreach ($path in $required) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Expected Gitleaks artifact is missing: $path"
        }
    }

    $installedWorkflow = [System.IO.File]::ReadAllText(
        (Join-Path $freshRepo '.github\workflows\gitleaks.yml')
    )
    $workflowRequirements = @{
        'the pinned Gitleaks CLI release' = 'GITLEAKS_VERSION:\s+''8\.30\.1'''
        'the pinned Linux archive checksum' = '551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb'
        'a full Git history checkout' = 'fetch-depth:\s+0'
        'an explicit full-history scan' = 'gitleaks git .*--log-opts="--all"'
        'a fail-closed checksum check' = 'sha256sum --check --strict'
    }
    foreach ($requirement in $workflowRequirements.GetEnumerator()) {
        if ($installedWorkflow -notmatch $requirement.Value) {
            throw "The installed workflow is missing $($requirement.Key)."
        }
    }
    if ($installedWorkflow -match 'gitleaks/gitleaks-action') {
        throw 'The installed workflow still uses the organization-licensed Gitleaks action.'
    }
    if ($installedWorkflow -match 'GITLEAKS_LICENSE') {
        throw 'The installed workflow unexpectedly depends on a Gitleaks license secret.'
    }

    $equivalentRepo = Join-Path $testRoot 'equivalent'
    New-Item -ItemType Directory -Path $equivalentRepo -Force | Out-Null
    & git.exe -C $equivalentRepo init --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to initialize the equivalent-hook repository.'
    }
    $hook = Join-Path $equivalentRepo '.git\hooks\pre-commit'
    [System.IO.File]::WriteAllText(
        $hook,
        "#!/bin/sh`nGITLEAKS=`"/custom/gitleaks`"`nexec `"`$GITLEAKS`" git --pre-commit --staged --redact --no-banner`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $equivalentRejected = $false
    try {
        & $tool -Repository $equivalentRepo | Out-Null
    }
    catch {
        $equivalentRejected = $_.Exception.Message -match 'manual integration'
    }
    if (-not $equivalentRejected) {
        throw 'A non-identical pre-commit hook was accepted.'
    }

    $commentOnlyRepo = Join-Path $testRoot 'comment-only'
    New-Item -ItemType Directory -Path $commentOnlyRepo -Force | Out-Null
    & git.exe -C $commentOnlyRepo init --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to initialize the comment-only-hook repository.'
    }
    $commentOnlyHook = Join-Path $commentOnlyRepo '.git\hooks\pre-commit'
    [System.IO.File]::WriteAllText(
        $commentOnlyHook,
        "# gitleaks git --pre-commit --staged --redact --no-banner`nexit 0`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $commentOnlyRejected = $false
    try {
        & $tool -Repository $commentOnlyRepo | Out-Null
    }
    catch {
        $commentOnlyRejected = $_.Exception.Message -match 'manual integration'
    }
    if (-not $commentOnlyRejected) {
        throw 'A no-op pre-commit hook with Gitleaks tokens only in a comment was accepted.'
    }

    Write-Output 'Enable-Gitleaks regression test passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
