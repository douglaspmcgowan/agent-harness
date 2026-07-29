[CmdletBinding()]
param(
    [string]$CapsuleRoot
)

$ErrorActionPreference = 'Stop'
if (-not $CapsuleRoot) {
    $CapsuleRoot = Split-Path -Parent $PSScriptRoot
}
$integrityPath = Join-Path $CapsuleRoot 'manifests\integrity.json'
$files = @(Get-ChildItem -LiteralPath $CapsuleRoot -File -Recurse -Force | Where-Object {
    $_.FullName -ne $integrityPath
} | Sort-Object FullName | ForEach-Object {
    [ordered]@{
        path = $_.FullName.Substring($CapsuleRoot.Length).TrimStart('\').Replace('\', '/')
        bytes = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})
[System.IO.File]::WriteAllText(
    $integrityPath,
    (([ordered]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        files = $files
    }) | ConvertTo-Json -Depth 6) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{ Result = 'PASS'; Files = $files.Count }
