$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'BwsCredentialStore.psm1'
$target = 'AgentHarness/Test/' + [Guid]::NewGuid().ToString('N')
$expected = 'credential-test-' + [Guid]::NewGuid().ToString('N')
$secureExpected = ConvertTo-SecureString $expected -AsPlainText -Force

function ConvertFrom-TestSecureString {
    param([Security.SecureString]$Value)

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

try {
    Import-Module -Name $modulePath -Force
    Set-BwsMachineToken -TargetName $target -AccessToken $secureExpected

    $actualSecure = Get-BwsMachineToken -TargetName $target
    $actual = ConvertFrom-TestSecureString -Value $actualSecure
    if ($actual -cne $expected) {
        throw 'Credential Manager did not return the stored test credential.'
    }

    Remove-BwsMachineToken -TargetName $target
    $missingBlocked = $false
    try {
        Get-BwsMachineToken -TargetName $target | Out-Null
    }
    catch {
        $missingBlocked = $_.Exception.Message -match 'is not stored'
    }
    if (-not $missingBlocked) {
        throw 'A removed machine token was still readable.'
    }

    'BWS Credential Manager integration test passed.'
}
finally {
    try {
        Remove-BwsMachineToken -TargetName $target -ErrorAction SilentlyContinue
    }
    catch {
    }
    $actual = $null
    $expected = $null
    $actualSecure = $null
    $secureExpected = $null
    Remove-Module BwsCredentialStore -ErrorAction SilentlyContinue
}
