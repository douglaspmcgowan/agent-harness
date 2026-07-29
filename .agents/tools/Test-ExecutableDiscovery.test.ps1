$ErrorActionPreference = 'Stop'

$tool = Join-Path $PSScriptRoot 'Test-ExecutableDiscovery.ps1'
$root = Join-Path $env:TEMP ("executable-discovery-test-" + [Guid]::NewGuid().ToString('N'))
$existing = Join-Path $root 'existing'
$additional = Join-Path $root 'additional'

try {
    New-Item -ItemType Directory -Path $existing, $additional -Force | Out-Null
    $inputPath = "$existing;$existing"

    $first = & $tool `
        -UserPathOverride $inputPath `
        -MachinePathOverride '' `
        -ProcessPathOverride '' `
        -AdditionalUserPathDirectory $additional `
        -SkipStandardDirectories `
        -SkipFreshProcessVerification

    if (-not $first.userPathChanged) {
        throw 'The audit did not recommend adding an installed executable directory.'
    }
    if (@($first.pathAdded).Count -ne 1 -or $first.pathAdded[0] -ne $additional) {
        throw 'The audit did not add exactly the requested executable directory.'
    }
    $normalizedEntries = @($first.recommendedUserPath -split ';')
    if (@($normalizedEntries | Where-Object { $_ -eq $existing }).Count -ne 1) {
        throw 'The audit did not remove duplicate PATH entries while preserving the original directory.'
    }
    if ($normalizedEntries[0] -ne $additional) {
        throw 'The installed executable directory was not placed before existing PATH entries.'
    }

    $second = & $tool `
        -UserPathOverride $first.recommendedUserPath `
        -MachinePathOverride '' `
        -ProcessPathOverride '' `
        -AdditionalUserPathDirectory $additional `
        -SkipStandardDirectories `
        -SkipFreshProcessVerification

    if ($second.userPathChanged) {
        throw 'A second normalization pass was not idempotent.'
    }
    if (@($second.pathAdded).Count -ne 0) {
        throw 'A second normalization pass tried to add another PATH entry.'
    }

    $fresh = & $tool `
        -UserPathOverride $first.recommendedUserPath `
        -MachinePathOverride '' `
        -ProcessPathOverride '' `
        -AdditionalUserPathDirectory $additional `
        -SkipStandardDirectories
    if ($fresh.freshProcess.status -ne 'PASS' -or @($fresh.freshProcess.commands).Count -ne 15) {
        throw 'Fresh-process verification did not return one result per audited command.'
    }

    $standard = & $tool -SkipFreshProcessVerification
    $expectedHarnessTools = Join-Path $env:USERPROFILE '.agents\tools'
    $expectedLocalBin = Join-Path $env:USERPROFILE '.local\bin'
    if (@($standard.recommendedUserPath -split ';') -notcontains $expectedHarnessTools) {
        throw 'The normalized User PATH does not contain the stable installed harness-tools directory.'
    }
    if (@($standard.pathAdded | Where-Object { $_ -match '\\Worktrees\\' }).Count -gt 0) {
        throw 'The audit recommended an ephemeral worktree directory for the User PATH.'
    }
    if ((Test-Path -LiteralPath $expectedLocalBin -PathType Container) -and
        @($standard.recommendedUserPath -split ';') -notcontains $expectedLocalBin) {
        throw 'The normalized User PATH does not contain the standard per-user pipx executable directory.'
    }

    $broken = Join-Path $root 'broken'
    New-Item -ItemType Directory -Path $broken -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $broken 'python.exe'), 'broken shim', [Text.Encoding]::ASCII)
    [IO.File]::WriteAllText((Join-Path $broken 'dvc.exe'), 'broken shim', [Text.Encoding]::ASCII)
    $brokenAudit = & $tool `
        -UserPathOverride $broken `
        -MachinePathOverride '' `
        -ProcessPathOverride $broken `
        -SkipStandardDirectories `
        -SkipFreshProcessVerification
    $brokenPython = @($brokenAudit.tools | Where-Object name -eq 'python')[0]
    if ($brokenPython.availableAfterNormalization) {
        throw 'The audit reported an unusable Python shim as available.'
    }
    $brokenDvc = @($brokenAudit.tools | Where-Object name -eq 'dvc')[0]
    if ($brokenDvc.availableAfterNormalization) {
        throw 'The audit reported an unusable DVC shim as available.'
    }

    $beforeApply = [Environment]::GetEnvironmentVariable('Path', 'User')
    & $tool `
        -UserPathOverride $inputPath `
        -MachinePathOverride '' `
        -ProcessPathOverride '' `
        -AdditionalUserPathDirectory $additional `
        -SkipStandardDirectories `
        -SkipFreshProcessVerification `
        -ApplyUserPath `
        -WhatIf | Out-Null
    $afterApply = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($beforeApply -cne $afterApply) {
        throw 'The WhatIf audit changed the real User PATH.'
    }

    'Executable discovery normalization test passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
