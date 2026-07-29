$ErrorActionPreference = 'Stop'

$root = Join-Path $env:TEMP ('feedback-skill-test-' + [Guid]::NewGuid().ToString('N'))
$repo = Join-Path $root 'repo'
New-Item -ItemType Directory -Path $repo -Force | Out-Null

try {
    $script = Join-Path $PSScriptRoot 'Record-Feedback.ps1'
    $result = & $script `
        -Id 'feedback-20260726-test-record' `
        -Incident 'An agent skipped the requested verifier.' `
        -RootCauseStatus reproduced `
        -Scope project,platform `
        -Enforcement rule,test,verifier `
        -Evidence 'VERIFY.md','test transcript' `
        -Artifact 'AGENTS.md','VERIFY.md' `
        -Verification 'Test-AgentProjectState.cmd' `
        -Repository $repo

    $log = Join-Path $repo '.agents\feedback\FEEDBACK-LOG.md'
    if (-not (Test-Path -LiteralPath $log)) { throw 'Feedback log was not created.' }
    $content = Get-Content -Raw -LiteralPath $log
    foreach ($expected in @(
        'feedback-20260726-test-record',
        '  - project',
        '  - platform',
        '  - rule',
        '  - test',
        '  - verifier'
    )) {
        if (-not $content.Contains($expected)) { throw "Feedback log lacks: $expected" }
    }
    if (@($result.Enforcement).Count -ne 3) { throw 'Enforcement did not remain list-valued.' }

    $scriptText = Get-Content -Raw -LiteralPath $script
    if (-not $scriptText.Contains("'feedback\FEEDBACK-LOG.md'")) {
        throw 'Shared feedback log routing is missing.'
    }

    $blocked = $false
    try {
        & $script `
            -Id 'feedback-20260726-secret-test' `
            -Incident 'token=forbidden-value' `
            -RootCauseStatus hypothesis `
            -Scope project `
            -Enforcement rule `
            -Evidence 'chat' `
            -Repository $repo | Out-Null
    }
    catch {
        $blocked = $true
    }
    if (-not $blocked) { throw 'Credential-like value was not rejected.' }

    Write-Output 'Feedback skill tests passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
