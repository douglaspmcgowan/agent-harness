[CmdletBinding()]
param(
    [string]$CredentialTarget = 'AgentHarness/BitwardenSecretsManager',

    [Security.SecureString]$AccessToken,

    [string]$CredentialStoreModulePath = (Join-Path $PSScriptRoot 'BwsCredentialStore.psm1')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CredentialStoreModulePath -PathType Leaf)) {
    throw "The BWS Credential Manager module is missing: $CredentialStoreModulePath"
}

Import-Module -Name $CredentialStoreModulePath -Force
if (-not $AccessToken) {
    $AccessToken = Read-Host `
        -Prompt 'Paste the read-only Bitwarden Secrets Manager machine-account token' `
        -AsSecureString
}
if ($AccessToken.Length -eq 0) {
    throw 'No Bitwarden Secrets Manager machine-account token was entered.'
}

try {
    Set-BwsMachineToken -TargetName $CredentialTarget -AccessToken $AccessToken
    Write-Output "Stored the BWS machine token in Windows Credential Manager target '$CredentialTarget'."
}
finally {
    $AccessToken.Dispose()
    $AccessToken = $null
}
