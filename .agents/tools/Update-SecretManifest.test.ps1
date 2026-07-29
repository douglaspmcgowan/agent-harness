$ErrorActionPreference = 'Stop'

$tool = Join-Path $PSScriptRoot 'Update-SecretManifest.ps1'
$root = Join-Path $env:TEMP ('secret-manifest-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $root 'secret-manifest.json'),
        "{`r`n  `"schemaVersion`": 1,`r`n  `"project`": `"fixture`",`r`n  `"variables`": []`r`n}`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        (Join-Path $root '.env.example'),
        "PROJECT_DATA_ROOT=`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    & $tool -Repository $root | Out-Null
    & $tool -Repository $root -Check | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $root 'secret-manifest.md')) 'Generated secret-manifest.md is missing.'

    $manifest = [System.IO.File]::ReadAllText((Join-Path $root 'secret-manifest.json')) | ConvertFrom-Json
    $manifest.variables[0] | Add-Member -NotePropertyName value -NotePropertyValue 'forbidden'
    [System.IO.File]::WriteAllText(
        (Join-Path $root 'secret-manifest.json'),
        (($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )

    $rejected = $false
    try { & $tool -Repository $root -Check | Out-Null }
    catch { $rejected = $_.Exception.Message -match 'Unsupported field.*value|forbidden' }
    Assert-True $rejected 'Secret manifest checker accepted a persisted value field.'

    Write-Output 'Update-SecretManifest tests passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
