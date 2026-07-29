[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'Sync-PortableContract.ps1'
$testRoot = Join-Path $env:TEMP ('sync-portable-contract-test-' + [guid]::NewGuid().ToString('N'))

try {
    $repo = Join-Path $testRoot 'repo'
    $backup = Join-Path $testRoot 'backups'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git.exe -C $repo init --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to initialize the disposable repository.'
    }
    $ambientHook = Join-Path $repo '.git\hooks\pre-commit'
    if (Test-Path -LiteralPath $ambientHook) {
        Remove-Item -LiteralPath $ambientHook -Force
    }

    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $repo 'AGENTS.md'),
        "# Project instructions`r`n`r`n<!-- agent-harness:portable-principles:v2:start -->`r`nold`r`n<!-- agent-harness:portable-principles:v2:end -->`r`n`r`nKeep this project rule.`r`n",
        $utf8
    )

    & $tool -Repository $repo -BackupRoot $backup | Out-Null

    $actual = [System.IO.File]::ReadAllText((Join-Path $repo 'AGENTS.md'), $utf8)
    if (-not $actual.Contains('<!-- agent-harness:portable:v3:start -->')) {
        throw 'Legacy contract sync did not delegate to the canonical v3 project bootstrap.'
    }
    if ($actual.Contains('agent-harness:portable-principles:v2')) {
        throw 'Legacy contract sync left or added a v2 managed block.'
    }
    if (-not $actual.Contains('Keep this project rule.')) {
        throw 'Legacy contract sync discarded project-specific content.'
    }
    if (Test-Path -LiteralPath (Join-Path $repo 'VERIFY.md')) {
        throw 'Legacy contract sync added the retired VERIFY.md file.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $repo 'TASK.md') -PathType Leaf)) {
        throw 'Legacy contract sync did not install the canonical TASK.md state file.'
    }

    Write-Output 'Sync-PortableContract v3 delegation regression test passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
