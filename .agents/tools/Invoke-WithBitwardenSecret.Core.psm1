Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-WindowsCommandLineArgument {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashes += 1
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($backslashes * 2) + 1)) -join '')
            [void]$builder.Append('"')
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) {
            [void]$builder.Append(('\' * $backslashes) -join '')
            $backslashes = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashes -gt 0) {
        [void]$builder.Append(('\' * ($backslashes * 2)) -join '')
    }
    [void]$builder.Append('"')
    $builder.ToString()
}

function Invoke-IsolatedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [hashtable]$EnvironmentToAdd = @{},

        [string[]]$EnvironmentToInherit = @(),

        [string[]]$EnvironmentToRemove = @()
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.Arguments = (@(
        $ArgumentList | ForEach-Object {
            ConvertTo-WindowsCommandLineArgument -Value ([string]$_)
        }
    ) -join ' ')
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    # PowerShell 5.1 can unwrap the initially empty StringDictionary to $null.
    # Build a narrow child environment so unrelated parent credentials never cross the boundary.
    [void]$startInfo.EnvironmentVariables
    $processEnvironment = $startInfo.EnvironmentVariables
    $processEnvironment.Clear()
    $baselineEnvironment = @(
        'SystemRoot', 'WINDIR', 'ComSpec', 'TEMP', 'TMP', 'USERPROFILE',
        'HOMEDRIVE', 'HOMEPATH', 'APPDATA', 'LOCALAPPDATA', 'PROGRAMDATA',
        'ProgramFiles', 'ProgramFiles(x86)', 'ProgramW6432', 'PATH', 'PATHEXT',
        'PROCESSOR_ARCHITECTURE', 'NUMBER_OF_PROCESSORS'
    )
    foreach ($name in @($baselineEnvironment + $EnvironmentToInherit | Sort-Object -Unique)) {
        $value = [Environment]::GetEnvironmentVariable([string]$name, 'Process')
        if ($null -ne $value) {
            $processEnvironment[[string]$name] = [string]$value
        }
    }
    foreach ($name in $EnvironmentToRemove) {
        if ($processEnvironment.ContainsKey($name)) {
            [void]$processEnvironment.Remove($name)
        }
    }
    foreach ($entry in $EnvironmentToAdd.GetEnumerator()) {
        $processEnvironment[[string]$entry.Key] = [string]$entry.Value
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw 'The approved child process did not start.'
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    }
    finally {
        foreach ($name in @($EnvironmentToAdd.Keys)) {
            if ($processEnvironment.ContainsKey([string]$name)) {
                [void]$processEnvironment.Remove([string]$name)
            }
        }
        $process.Dispose()
    }
}

function Protect-ProcessOutput {
    param(
        [AllowEmptyString()]
        [string]$Text,

        [string[]]$SensitiveValues
    )

    $safe = $Text
    foreach ($value in @($SensitiveValues | Where-Object { -not [string]::IsNullOrEmpty($_) })) {
        $safe = $safe.Replace([string]$value, '[REDACTED]')
    }
    $safe
}

function Expand-TrustedPolicyTokens {
    param(
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [hashtable]$TrustedTokens
    )

    $expanded = [regex]::Replace(
        $Value,
        '%(?<name>[A-Za-z][A-Za-z0-9()]*)%',
        [Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $name = $match.Groups['name'].Value
            if (-not $TrustedTokens.ContainsKey($name)) {
                throw "The command policy contains an unsupported trusted-path token: %$name%."
            }
            return [string]$TrustedTokens[$name]
        }
    )
    if ($expanded -match '%[^%]+%') {
        throw 'The command policy contains an unresolved trusted-path token.'
    }
    $expanded
}

function Get-BwsCommandPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z0-9][a-z0-9._-]*$')]
        [string]$CommandId,

        [Parameter(Mandatory = $true)]
        [string]$AllowlistPath,

        [Parameter(Mandatory = $true)]
        [string]$TrustedUserProfile,

        [Parameter(Mandatory = $true)]
        [string]$TrustedProgramFiles
    )

if (-not (Test-Path -LiteralPath $AllowlistPath -PathType Leaf)) {
    throw "Credential command allowlist is missing: $AllowlistPath"
}

$policy = Get-Content -Raw -LiteralPath $AllowlistPath | ConvertFrom-Json
if ([int]$policy.schemaVersion -ne 3) {
    throw 'The BWS credential allowlist must use schemaVersion 3.'
}

$matches = @($policy.commands | Where-Object {
    [string]::Equals([string]$_.commandId, $CommandId, [StringComparison]::Ordinal)
})
if ($matches.Count -ne 1) {
    throw "CommandId '$CommandId' must match exactly one BWS credential allowlist record."
}
$approval = $matches[0]

$trustedTokens = [hashtable]::new([StringComparer]::OrdinalIgnoreCase)
$trustedTokens['USERPROFILE'] = [IO.Path]::GetFullPath($TrustedUserProfile)
$trustedTokens['ProgramFiles'] = [IO.Path]::GetFullPath($TrustedProgramFiles)

$approvedExecutable = Expand-TrustedPolicyTokens -Value ([string]$approval.executable) -TrustedTokens $trustedTokens
$resolvedExecutable = if (Test-Path -LiteralPath $approvedExecutable -PathType Leaf) {
    (Resolve-Path -LiteralPath $approvedExecutable).Path
}
else {
    throw "The approved executable does not exist: $($approval.executable)"
}
$approvedWorkingDirectory = Expand-TrustedPolicyTokens -Value ([string]$approval.workingDirectory) -TrustedTokens $trustedTokens
if (-not (Test-Path -LiteralPath $approvedWorkingDirectory -PathType Container)) {
    throw "The approved working directory does not exist: $($approval.workingDirectory)"
}
$resolvedWorkingDirectory = (Resolve-Path -LiteralPath $approvedWorkingDirectory).Path
$approvedArguments = @($approval.argumentList | ForEach-Object {
    Expand-TrustedPolicyTokens -Value ([string]$_) -TrustedTokens $trustedTokens
})
$projectId = [string]$approval.projectId
if ([string]::IsNullOrWhiteSpace($projectId)) {
    throw "CommandId '$CommandId' has no approved Bitwarden project ID."
}

$bindings = @($approval.secretBindings)
if ($bindings.Count -eq 0) {
    throw "CommandId '$CommandId' has no approved secret bindings."
}

$approvedInheritedEnvironment = @($approval.inheritedEnvironment)
$inheritedNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($nameValue in $approvedInheritedEnvironment) {
    $name = [string]$nameValue
    if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or
        $name -in @('BWS_ACCESS_TOKEN', 'BW_SESSION') -or
        -not $inheritedNames.Add($name)) {
        throw "CommandId '$CommandId' contains an invalid, reserved, or duplicate inherited environment name."
    }
}

$bindingVariables = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$bindingIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($binding in $bindings) {
    $environmentVariable = [string]$binding.environmentVariable
    $secretId = [string]$binding.secretId
    if ($environmentVariable -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or
        $environmentVariable -in @('BWS_ACCESS_TOKEN', 'BW_SESSION')) {
        throw "CommandId '$CommandId' contains an invalid or reserved secret destination."
    }
    if ([string]::IsNullOrWhiteSpace($secretId)) {
        throw "CommandId '$CommandId' contains an empty Bitwarden secret ID."
    }
    if (-not $bindingVariables.Add($environmentVariable)) {
        throw "CommandId '$CommandId' contains a duplicate secret destination."
    }
    if (-not $bindingIds.Add($secretId)) {
        throw "CommandId '$CommandId' contains a duplicate Bitwarden secret ID."
    }
    if ($inheritedNames.Contains($environmentVariable)) {
        throw "CommandId '$CommandId' cannot inherit a secret destination from the parent environment."
    }
}

$allSecretDestinations = @(
    $policy.commands |
        ForEach-Object { @($_.secretBindings) } |
        ForEach-Object { [string]$_.environmentVariable } |
        Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*$' } |
        Sort-Object -Unique
)

    [pscustomobject]@{
        PSTypeName = 'AgentHarness.BwsCommandPlan'
        CommandId = $CommandId
        Executable = $resolvedExecutable
        Arguments = $approvedArguments
        WorkingDirectory = $resolvedWorkingDirectory
        ProjectId = $projectId
        Bindings = $bindings
        InheritedEnvironment = $approvedInheritedEnvironment
        AllSecretDestinations = $allSecretDestinations
    }
}

function Invoke-BwsCommandCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [string]$BwsPath,

        [Parameter(Mandatory = $true)]
        [Security.SecureString]$MachineToken
    )

if ($Plan.PSObject.TypeNames[0] -ne 'AgentHarness.BwsCommandPlan') {
    throw 'The BWS command plan was not produced by Get-BwsCommandPlan.'
}
if (-not (Test-Path -LiteralPath $BwsPath -PathType Leaf)) {
    throw "Bitwarden Secrets Manager CLI is missing: $BwsPath"
}
$resolvedBwsPath = (Resolve-Path -LiteralPath $BwsPath).Path
$resolvedExecutable = [string]$Plan.Executable
$approvedArguments = @($Plan.Arguments)
$resolvedWorkingDirectory = [string]$Plan.WorkingDirectory
$projectId = [string]$Plan.ProjectId
$bindings = @($Plan.Bindings)
$approvedInheritedEnvironment = @($Plan.InheritedEnvironment)
$allSecretDestinations = @($Plan.AllSecretDestinations)

$tokenPointer = [IntPtr]::Zero
$token = $null
$secretEnvironment = @{}
$sensitiveValues = [Collections.Generic.List[string]]::new()
try {
    $tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($MachineToken)
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
    [void]$sensitiveValues.Add($token)

    foreach ($binding in $bindings) {
        $lookup = Invoke-IsolatedProcess `
            -FileName $resolvedBwsPath `
            -ArgumentList @('secret', 'get', [string]$binding.secretId, '--output', 'json') `
            -WorkingDirectory $resolvedWorkingDirectory `
            -EnvironmentToAdd @{ BWS_ACCESS_TOKEN = $token } `
            -EnvironmentToInherit $approvedInheritedEnvironment `
            -EnvironmentToRemove (@('BWS_ACCESS_TOKEN', 'BW_SESSION') + $allSecretDestinations)
        if ($lookup.ExitCode -ne 0) {
            throw 'Bitwarden Secrets Manager could not retrieve an approved secret.'
        }

        try {
            $record = $lookup.StdOut | ConvertFrom-Json
        }
        catch {
            throw 'Bitwarden Secrets Manager returned an invalid secret record.'
        }
        if (-not [string]::Equals([string]$record.id, [string]$binding.secretId, [StringComparison]::Ordinal) -or
            -not [string]::Equals([string]$record.projectId, $projectId, [StringComparison]::Ordinal)) {
            throw 'Bitwarden Secrets Manager returned a secret outside the approved Bitwarden project.'
        }
        if (-not ($record.PSObject.Properties.Name -contains 'value') -or
            [string]::IsNullOrEmpty([string]$record.value)) {
            throw 'Bitwarden Secrets Manager returned no secret value.'
        }

        $value = [string]$record.value
        $secretEnvironment[[string]$binding.environmentVariable] = $value
        [void]$sensitiveValues.Add($value)
        $record.value = $null
        $record = $null
        $lookup = $null
    }

    $targetResult = Invoke-IsolatedProcess `
        -FileName $resolvedExecutable `
        -ArgumentList $approvedArguments `
        -WorkingDirectory $resolvedWorkingDirectory `
        -EnvironmentToAdd $secretEnvironment `
        -EnvironmentToInherit $approvedInheritedEnvironment `
        -EnvironmentToRemove (@('BWS_ACCESS_TOKEN', 'BW_SESSION') + $allSecretDestinations)

    $safeStdOut = Protect-ProcessOutput -Text $targetResult.StdOut -SensitiveValues $sensitiveValues
    $safeStdErr = Protect-ProcessOutput -Text $targetResult.StdErr -SensitiveValues $sensitiveValues
    if (-not [string]::IsNullOrEmpty($safeStdOut)) {
        Write-Output $safeStdOut.TrimEnd()
    }
    if (-not [string]::IsNullOrEmpty($safeStdErr)) {
        Write-Warning $safeStdErr.TrimEnd()
    }
    if ($targetResult.ExitCode -ne 0) {
        throw "Allowlisted credential-dependent command failed with exit code $($targetResult.ExitCode)."
    }
}
finally {
    foreach ($key in @($secretEnvironment.Keys)) {
        $secretEnvironment[$key] = $null
        [void]$secretEnvironment.Remove($key)
    }
    $sensitiveValues.Clear()
    $token = $null
    if ($tokenPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
    }
}

}

Export-ModuleMember -Function Get-BwsCommandPlan, Invoke-BwsCommandCore
