$ErrorActionPreference = 'Stop'

$harnessRoot = Split-Path $PSScriptRoot -Parent
$manager = Join-Path $PSScriptRoot 'Manage-Harness.ps1'
$ensureLegacy = Join-Path $PSScriptRoot 'Ensure-AgentProject.ps1'
$initializeLegacy = Join-Path $PSScriptRoot 'Initialize-AgentProject.ps1'
$verifyLegacy = Join-Path $PSScriptRoot 'Test-AgentProjectState.ps1'
$testId = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$root = Join-Path $env:TEMP "pbc-$testId"
$testHome = Join-Path $env:TEMP "pbh-$testId"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-TestRepository([string]$Name) {
    $path = Join-Path $root $Name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    & git.exe -c init.templateDir= -C $path init --quiet
    if ($LASTEXITCODE -ne 0) { throw "Could not initialize fixture repository: $path" }
    return $path
}

function Get-ProjectFileSet([string]$Repository) {
    return @(
        Get-ChildItem -LiteralPath $Repository -Recurse -File -Force |
            Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
            ForEach-Object { $_.FullName.Substring($Repository.Length).TrimStart('\').Replace('\', '/') } |
            Sort-Object
    )
}

function Assert-SameFileSet([string]$ExpectedRepository, [string]$ActualRepository, [string]$Label) {
    $expected = Get-ProjectFileSet $ExpectedRepository
    $actual = Get-ProjectFileSet $ActualRepository
    Assert-True (($expected -join "`n") -ceq ($actual -join "`n")) (
        "$Label produced a different project file set.`nExpected:`n$($expected -join "`n")`nActual:`n$($actual -join "`n")"
    )
}

function Assert-ThrowsContaining([scriptblock]$Action, [string]$Pattern, [string]$Message) {
    $thrown = $false
    try { & $Action | Out-Null }
    catch {
        $thrown = $_.Exception.Message -match $Pattern
    }
    Assert-True $thrown $Message
}

try {
    New-Item -ItemType Directory -Path $root, $testHome -Force | Out-Null
    $canonical = New-TestRepository 'canonical'
    $ensureRepo = New-TestRepository 'legacy-ensure'
    $initializeRepo = New-TestRepository 'legacy-initialize'
    $preserveRepo = New-TestRepository 'preserve'
    $whatIfRepo = New-TestRepository 'what-if'

    & $ensureLegacy `
        -HarnessRoot $harnessRoot `
        -HomeRoot $testHome `
        -Repository $whatIfRepo `
        -ProjectName 'what-if' `
        -WhatIf | Out-Null
    Assert-True ((Get-ProjectFileSet $whatIfRepo).Count -eq 0) 'Ensure-AgentProject -WhatIf wrote project files.'

    & $manager -Action EnsureProject -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $canonical -ProjectName 'canonical' | Out-Null
    & $ensureLegacy -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $ensureRepo -ProjectName 'legacy-ensure' | Out-Null
    & $initializeLegacy -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $initializeRepo -ProjectName 'legacy-initialize' | Out-Null

    Assert-SameFileSet $canonical $ensureRepo 'Ensure-AgentProject.ps1'
    Assert-SameFileSet $canonical $initializeRepo 'Initialize-AgentProject.ps1'

    foreach ($repository in @($canonical, $ensureRepo, $initializeRepo)) {
        foreach ($relative in @(
            'AGENTS.md',
            'CLAUDE.md',
            '.cursor\rules\00-project-contract.mdc',
            'TASK.md',
            'STATUS.md',
            'LOG.md',
            'BACKBURNER.md',
            'MAP.md',
            'DESIGN.md',
            'MEMORY.md',
            'skills-manifest.json',
            'data-manifest.yaml',
            'secret-manifest.json',
            'secret-manifest.md',
            '.env.example',
            '.gitleaks.toml',
            '.github\workflows\gitleaks.yml',
            '.agents\feedback\FEEDBACK-LOG.md'
        )) {
            Assert-True (Test-Path -LiteralPath (Join-Path $repository $relative) -PathType Leaf) "Missing v3 project file: $relative"
        }
        foreach ($legacy in @('CURRENT-TASK.md', 'WORK_QUEUE.md', 'VERIFY.md')) {
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $repository $legacy))) "Legacy active-state file was created: $legacy"
        }
        $hookPath = (& git.exe -C $repository rev-parse --git-path hooks).Trim()
        if (-not [System.IO.Path]::IsPathRooted($hookPath)) {
            $hookPath = Join-Path $repository $hookPath
        }
        Assert-True (Test-Path -LiteralPath (Join-Path $hookPath 'pre-commit') -PathType Leaf) 'Project bootstrap omitted the Gitleaks pre-commit hook.'
        $agents = [System.IO.File]::ReadAllText((Join-Path $repository 'AGENTS.md'))
        Assert-True $agents.Contains('<!-- agent-harness:portable:v3:start -->') 'Project contract lacks portable:v3.'
        & $manager -Action VerifyProject -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $repository | Out-Null
        & $verifyLegacy -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $repository | Out-Null
    }

    $preservedMap = "# Project-owned map`r`n`r`nUnique preservation marker.`r`n"
    [System.IO.File]::WriteAllText((Join-Path $preserveRepo 'MAP.md'), $preservedMap, [System.Text.UTF8Encoding]::new($false))
    & $manager -Action EnsureProject -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $preserveRepo -ProjectName 'preserve' | Out-Null
    Assert-True (
        [System.IO.File]::ReadAllText((Join-Path $preserveRepo 'MAP.md')) -ceq $preservedMap
    ) 'EnsureProject overwrote a non-placeholder project MAP.md.'

    foreach ($legacy in @('CURRENT-TASK.md', 'WORK_QUEUE.md', 'VERIFY.md')) {
        [System.IO.File]::WriteAllText((Join-Path $canonical $legacy), "# stale`r`n", [System.Text.UTF8Encoding]::new($false))
        $pattern = [regex]::Escape($legacy)
        Assert-ThrowsContaining {
            & $manager -Action EnsureProject -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $canonical
        } $pattern "Canonical ensure accepted legacy active state: $legacy"
        Assert-ThrowsContaining {
            & $manager -Action VerifyProject -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $canonical
        } $pattern "Canonical verifier accepted legacy active state: $legacy"
        Assert-ThrowsContaining {
            & $verifyLegacy -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $canonical
        } $pattern "Legacy verifier accepted legacy active state: $legacy"
        Remove-Item -LiteralPath (Join-Path $canonical $legacy) -Force
    }

    $validDataManifest = [System.IO.File]::ReadAllText((Join-Path $canonical 'data-manifest.yaml'))
    $invalidData = @'
version: 2
project: "canonical"
data_root_env: "PROJECT_DATA_ROOT"
assets:
  - id: "missing-authority"
    project: "canonical"
    class: "portable-export"
    local_destination: "inputs/export.zip"
    adapter: "MissingAdapter.ps1"
    version_rule: "latest"
    integrity_rule: "SHA-256"
    restore_verifier: "compare hash"
'@
    [System.IO.File]::WriteAllText((Join-Path $canonical 'data-manifest.yaml'), $invalidData, [System.Text.UTF8Encoding]::new($false))
    Assert-ThrowsContaining {
        & $manager -Action VerifyProject -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $canonical
    } 'authority|adapter' 'Canonical verifier accepted an invalid populated data manifest.'

    [System.IO.File]::WriteAllText((Join-Path $canonical 'data-manifest.yaml'), $validDataManifest, [System.Text.UTF8Encoding]::new($false))
    $unsafeSecretManifest = @'
{
  "schemaVersion": 1,
  "project": "canonical",
  "variables": [
    {
      "name": "EXAMPLE_TOKEN",
      "purpose": "fixture",
      "source": "runtime injection",
      "provider": "Bitwarden Secrets Manager",
      "trustBoundary": "development",
      "owner": "fixture",
      "rotation": "on compromise",
      "consumers": [],
      "status": "classified",
      "value": "forbidden"
    }
  ]
}
'@
    [System.IO.File]::WriteAllText((Join-Path $canonical 'secret-manifest.json'), $unsafeSecretManifest, [System.Text.UTF8Encoding]::new($false))
    Assert-ThrowsContaining {
        & $manager -Action VerifyProject -HarnessRoot $harnessRoot -HomeRoot $testHome -Repository $canonical
    } 'value|forbidden' 'Canonical verifier accepted a secret value field.'

    Write-Output 'Project bootstrap compatibility tests passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
    if (Test-Path -LiteralPath $testHome) {
        Remove-Item -LiteralPath $testHome -Recurse -Force
    }
}
