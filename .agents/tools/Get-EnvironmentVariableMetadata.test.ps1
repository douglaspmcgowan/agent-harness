$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'Get-EnvironmentVariableMetadata.ps1'
$name = 'HARNESS_METADATA_PROBE_TEST'
$previous = [Environment]::GetEnvironmentVariable($name, 'Process')

try {
    [Environment]::SetEnvironmentVariable($name, 'synthetic-value', 'Process')
    $result = @(& $script -Pattern '^HARNESS_METADATA_PROBE_TEST$' -Scope Process)

    if ($result.Count -ne 1) {
        throw "Expected one metadata row; received $($result.Count)."
    }
    if ($result[0].Name -ne $name -or $result[0].Scope -ne 'Process' -or
        -not $result[0].IsSet -or $result[0].Length -ne 15) {
        throw 'Metadata row did not describe the synthetic variable correctly.'
    }
    if (($result | Out-String).Contains('synthetic-value')) {
        throw 'Probe output exposed the environment-variable value.'
    }

    $missing = @(& $script -Pattern '^HARNESS_METADATA_PROBE_MISSING$' -Scope Process)
    if ($missing.Count -ne 0) {
        throw 'Missing-variable probe returned an unexpected row.'
    }

    $malformedBlocked = $false
    try {
        & $script -Pattern '[' -Scope Process | Out-Null
    }
    catch {
        $malformedBlocked = $true
    }
    if (-not $malformedBlocked) {
        throw 'Malformed regular expression was accepted.'
    }
}
finally {
    [Environment]::SetEnvironmentVariable($name, $previous, 'Process')
}

Write-Output 'Environment metadata probe tests passed.'
