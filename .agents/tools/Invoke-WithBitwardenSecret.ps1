[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9._-]*$')]
    [string]$CommandId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$trustedHomeRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
if ([string]::IsNullOrWhiteSpace($trustedHomeRoot)) {
    throw 'The Windows user-profile authority is unavailable.'
}
$trustedProgramFilesRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
if ([string]::IsNullOrWhiteSpace($trustedProgramFilesRoot)) {
    throw 'The Windows Program Files authority is unavailable.'
}
$trustedToolsRoot = Join-Path $trustedHomeRoot '.agents\tools'
$trustedBwsPath = Join-Path $trustedHomeRoot 'Tools\bws\bws.exe'
$trustedAllowlistPath = Join-Path $trustedToolsRoot 'bws-command-allowlist.json'
$trustedCredentialTarget = 'AgentHarness/BitwardenSecretsManager'
$trustedCredentialStoreModulePath = Join-Path $trustedToolsRoot 'BwsCredentialStore.psm1'
$trustedCoreModulePath = Join-Path $trustedToolsRoot 'Invoke-WithBitwardenSecret.Core.psm1'

foreach ($requiredPath in @(
    $trustedBwsPath,
    $trustedAllowlistPath,
    $trustedCredentialStoreModulePath,
    $trustedCoreModulePath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "The pinned Bitwarden broker dependency is missing: $requiredPath"
    }
}

Import-Module -Name $trustedCoreModulePath -Force
$plan = Get-BwsCommandPlan -CommandId $CommandId -AllowlistPath $trustedAllowlistPath `
    -TrustedUserProfile $trustedHomeRoot -TrustedProgramFiles $trustedProgramFilesRoot

Import-Module -Name $trustedCredentialStoreModulePath -Force
$machineToken = $null
try {
    $machineToken = Get-BwsMachineToken -TargetName $trustedCredentialTarget
    Invoke-BwsCommandCore -Plan $plan -BwsPath $trustedBwsPath -MachineToken $machineToken
}
finally {
    if ($machineToken) {
        $machineToken.Dispose()
    }
}
