Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not ([System.Management.Automation.PSTypeName]'AgentHarness.BwsCredentialNative').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace AgentHarness
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct NativeCredential
    {
        public UInt32 Flags;
        public UInt32 Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static class BwsCredentialNative
    {
        [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CredWrite(ref NativeCredential credential, UInt32 flags);

        [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CredRead(string target, UInt32 type, UInt32 flags, out IntPtr credential);

        [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CredDelete(string target, UInt32 type, UInt32 flags);

        [DllImport("advapi32.dll", SetLastError = false)]
        public static extern void CredFree(IntPtr buffer);
    }
}
'@ | Out-Null
}

$script:CredentialTypeGeneric = [uint32]1
$script:CredentialPersistLocalMachine = [uint32]2
$script:ErrorNotFound = 1168
$script:MaximumBlobBytes = 2560

function Assert-BwsCredentialTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    if ([string]::IsNullOrWhiteSpace($TargetName) -or
        $TargetName.Length -gt 256 -or
        $TargetName -notmatch '^[A-Za-z0-9._/-]+$') {
        throw 'Credential Manager target must contain only letters, digits, period, underscore, slash, or hyphen.'
    }
}

function Set-BwsMachineToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName,

        [Parameter(Mandatory = $true)]
        [Security.SecureString]$AccessToken
    )

    Assert-BwsCredentialTarget -TargetName $TargetName
    if ($AccessToken.Length -eq 0) {
        throw 'The Bitwarden Secrets Manager machine token cannot be empty.'
    }

    $blobSize = $AccessToken.Length * 2
    if ($blobSize -gt $script:MaximumBlobBytes) {
        throw 'The Bitwarden Secrets Manager machine token exceeds the Windows Credential Manager size limit.'
    }

    $bstr = [IntPtr]::Zero
    $blob = [IntPtr]::Zero
    try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)
        $blob = [Runtime.InteropServices.Marshal]::AllocCoTaskMem($blobSize)
        $bytes = [byte[]]::new($blobSize)
        [Runtime.InteropServices.Marshal]::Copy($bstr, $bytes, 0, $blobSize)
        [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $blob, $blobSize)
        [Array]::Clear($bytes, 0, $bytes.Length)

        $credential = [AgentHarness.NativeCredential]::new()
        $credential.Type = $script:CredentialTypeGeneric
        $credential.TargetName = $TargetName
        $credential.CredentialBlobSize = [uint32]$blobSize
        $credential.CredentialBlob = $blob
        $credential.Persist = $script:CredentialPersistLocalMachine
        $credential.UserName = 'Bitwarden Secrets Manager machine account'

        if (-not [AgentHarness.BwsCredentialNative]::CredWrite([ref]$credential, 0)) {
            $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw "Windows Credential Manager could not store the machine token (error $code)."
        }
    }
    finally {
        if ($blob -ne [IntPtr]::Zero) {
            for ($offset = 0; $offset -lt $blobSize; $offset += 1) {
                [Runtime.InteropServices.Marshal]::WriteByte($blob, $offset, 0)
            }
            [Runtime.InteropServices.Marshal]::FreeCoTaskMem($blob)
        }
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Get-BwsMachineToken {
    [CmdletBinding()]
    [OutputType([Security.SecureString])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    Assert-BwsCredentialTarget -TargetName $TargetName
    $credentialPointer = [IntPtr]::Zero
    if (-not [AgentHarness.BwsCredentialNative]::CredRead(
        $TargetName,
        $script:CredentialTypeGeneric,
        0,
        [ref]$credentialPointer
    )) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($code -eq $script:ErrorNotFound) {
            throw "A Bitwarden Secrets Manager machine token is not stored at Credential Manager target '$TargetName'."
        }
        throw "Windows Credential Manager could not read the machine token (error $code)."
    }

    try {
        $credential = [Runtime.InteropServices.Marshal]::PtrToStructure(
            $credentialPointer,
            [type][AgentHarness.NativeCredential]
        )
        if ($credential.CredentialBlobSize -eq 0 -or
            $credential.CredentialBlob -eq [IntPtr]::Zero -or
            ($credential.CredentialBlobSize % 2) -ne 0) {
            throw "The Credential Manager record at '$TargetName' has an invalid token payload."
        }

        $secure = [Security.SecureString]::new()
        for ($offset = 0; $offset -lt $credential.CredentialBlobSize; $offset += 2) {
            $secure.AppendChar([char][Runtime.InteropServices.Marshal]::ReadInt16(
                $credential.CredentialBlob,
                $offset
            ))
        }
        $secure.MakeReadOnly()
        return $secure
    }
    finally {
        if ($credentialPointer -ne [IntPtr]::Zero) {
            [AgentHarness.BwsCredentialNative]::CredFree($credentialPointer)
        }
    }
}

function Remove-BwsMachineToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    Assert-BwsCredentialTarget -TargetName $TargetName
    if (-not [AgentHarness.BwsCredentialNative]::CredDelete(
        $TargetName,
        $script:CredentialTypeGeneric,
        0
    )) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($code -ne $script:ErrorNotFound) {
            throw "Windows Credential Manager could not remove the machine token (error $code)."
        }
    }
}

Export-ModuleMember -Function Set-BwsMachineToken, Get-BwsMachineToken, Remove-BwsMachineToken
