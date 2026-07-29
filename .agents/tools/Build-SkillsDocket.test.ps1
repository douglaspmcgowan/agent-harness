$ErrorActionPreference = 'Stop'

$tool = Join-Path $PSScriptRoot 'Build-SkillsDocket.ps1'
$root = Join-Path $env:TEMP ("skills-docket-test-" + [Guid]::NewGuid().ToString('N'))
$outbox = Join-Path $root 'outbox'
$audit = Join-Path $root 'audit.jsonl'

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $record = [ordered]@{
        name = 'sample-skill'
        path = 'C:\portable\sample-skill\SKILL.md'
        portable_status = 'portable'
        severity = 'none'
        recommended_actions = @('Keep.')
    }
    [System.IO.File]::WriteAllText(
        $audit,
        ($record | ConvertTo-Json -Compress) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    $first = & $tool -AuditJsonl $audit -Outbox $outbox
    if ($first.CardsWritten -ne 1 -or $first.StaleArchived -ne 0) {
        throw 'Initial Docket build result was unexpected.'
    }

    [System.IO.File]::WriteAllText(
        (Join-Path $outbox 'stale-card.json'),
        '{"id":"stale-card"}' + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    $second = & $tool -AuditJsonl $audit -Outbox $outbox
    if ($second.CardsWritten -ne 1 -or $second.StaleArchived -ne 1) {
        throw 'Stale Docket card was not archived.'
    }
    if (Test-Path -LiteralPath (Join-Path $outbox 'stale-card.json')) {
        throw 'Stale Docket card remained in the canonical outbox.'
    }
    if (@(Get-ChildItem -LiteralPath $outbox -Filter '*.json' -File).Count -ne 1) {
        throw 'Canonical outbox does not contain exactly one current card.'
    }

    $lockPath = "$outbox.build.lock"
    $lock = [System.IO.File]::Open(
        $lockPath,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    try {
        $blocked = $false
        try {
            & $tool -AuditJsonl $audit -Outbox $outbox
        }
        catch {
            $blocked = $_.Exception.Message -match 'owns the outbox lock'
        }
        if (-not $blocked) {
            throw 'A concurrent Skills Docket build was not blocked.'
        }
    }
    finally {
        $lock.Dispose()
    }

    'Build-SkillsDocket regression test passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
