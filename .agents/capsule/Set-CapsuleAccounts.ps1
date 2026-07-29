[CmdletBinding()]
param(
    [string]$CapsuleRoot
)

$ErrorActionPreference = 'Stop'
if (-not $CapsuleRoot) {
    $CapsuleRoot = Split-Path -Parent $PSScriptRoot
}
$path = Join-Path $CapsuleRoot 'manifests\accounts.json'
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Account map is unavailable: $path"
}

$map = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($account in @($map.accounts)) {
    $current = [string]$account.accountIdentifier
    Write-Host ''
    Write-Host "$($account.service): $($account.purpose)"
    if ($account.identifierLabel) { Write-Host "Enter: $($account.identifierLabel)" }
    if ($account.exampleFormat) { Write-Host "Format example: $($account.exampleFormat)" }
    if ($account.whereToFind) { Write-Host "Find it: $($account.whereToFind)" }
    Write-Host 'Never enter a password, token, key, session value, or recovery code.'
    $prompt = if ($current) {
        "Account identifier [$current]"
    }
    else {
        'Account identifier'
    }
    $answer = Read-Host $prompt
    if (-not [string]::IsNullOrWhiteSpace($answer)) {
        $account.accountIdentifier = $answer.Trim()
    }
}

[System.IO.File]::WriteAllText(
    $path,
    ($map | ConvertTo-Json -Depth 6) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Updated safe account identifiers in $path"
Write-Host 'Run tools\Refresh-Integrity.cmd before moving Capsule.'
