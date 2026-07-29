$ErrorActionPreference = 'Stop'

$broker = Join-Path $PSScriptRoot 'Invoke-WithBitwardenSecret.ps1'
$core = Join-Path $PSScriptRoot 'Invoke-WithBitwardenSecret.Core.psm1'
$root = Join-Path $env:TEMP ("bws-broker-test-" + [Guid]::NewGuid().ToString('N'))
$mockBws = Join-Path $root 'bws.exe'
$child = Join-Path $root 'child.ps1'
$marker = Join-Path $root 'marker.txt'
$invocationLog = Join-Path $root 'bws-invocations.log'
$allowlist = Join-Path $root 'allowlist.json'
$powershell = (Get-Command powershell.exe -CommandType Application).Source

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$parseTokens = $null
$parseErrors = $null
$brokerAst = [Management.Automation.Language.Parser]::ParseFile(
    $broker,
    [ref]$parseTokens,
    [ref]$parseErrors
)
Assert-True ($parseErrors.Count -eq 0) 'The production broker entrypoint did not parse.'
$productionParameters = @(
    $brokerAst.ParamBlock.Parameters |
        ForEach-Object { $_.Name.VariablePath.UserPath }
)
Assert-True (
    $productionParameters.Count -eq 1 -and
    $productionParameters[0] -eq 'CommandId'
) 'The production broker entrypoint exposes caller-controlled dependency paths.'

$brokerSource = Get-Content -Raw -LiteralPath $broker
Assert-True ($brokerSource -match [regex]::Escape("Tools\bws\bws.exe")) 'The production broker does not pin the BWS executable.'
Assert-True ($brokerSource -match [regex]::Escape('bws-command-allowlist.json')) 'The production broker does not pin its allowlist.'
Assert-True ($brokerSource -match [regex]::Escape('AgentHarness/BitwardenSecretsManager')) 'The production broker does not pin its Credential Manager target.'
Assert-True ($brokerSource -match [regex]::Escape('BwsCredentialStore.psm1')) 'The production broker does not pin its credential module.'
Assert-True (
    $brokerSource -match '\[Environment\]::GetFolderPath\(\[Environment\+SpecialFolder\]::UserProfile\)'
) 'The production broker does not derive its trust root from the Windows user-profile authority.'
Assert-True (
    $brokerSource -match '\[Environment\]::GetFolderPath\(\[Environment\+SpecialFolder\]::ProgramFiles\)'
) 'The production broker does not derive its executable root from the Windows Program Files authority.'
Assert-True (
    $brokerSource -notmatch '\$PSScriptRoot|\$env:(USERPROFILE|PATH)|Get-Command\s+bws'
) 'The production broker derives a trust root from caller-controlled script or environment state.'

foreach ($forbiddenParameter in @(
    'BwsPath',
    'Allowlist',
    'CredentialTarget',
    'CredentialStoreModulePath'
)) {
    $redirectBlocked = $false
    try {
        & $broker -CommandId 'docket-sync' @{$forbiddenParameter = $root} | Out-Null
    }
    catch {
        $redirectBlocked = (
            $_.FullyQualifiedErrorId -match 'NamedParameterNotFound' -or
            $_.Exception.Message -match 'parameter.*cannot be found'
        )
    }
    Assert-True $redirectBlocked "The production broker accepted caller-controlled -$forbiddenParameter."
}

$coreSource = Get-Content -Raw -LiteralPath $core
Assert-True (
    $coreSource -notmatch 'Get-BwsMachineToken|BwsCredentialStore|CredentialTarget|Import-Module'
) 'The injectable broker core can retrieve the production machine credential.'

Import-Module -Name $core -Force

function Write-TestPolicy {
    param(
        [string]$ProjectId = 'project-unit',
        [string]$SecretId = 'secret-unit',
        [string]$WorkingDirectory = $root
    )

    $policy = [ordered]@{
        schemaVersion = 3
        commands = @(
            [ordered]@{
                commandId = 'docket-sync'
                purpose = 'Regression test'
                executable = $powershell
                argumentList = @(
                    '-NoProfile',
                    '-ExecutionPolicy',
                    'Bypass',
                    '-File',
                    '%USERPROFILE%\child.ps1',
                    '%USERPROFILE%\marker.txt'
                )
                workingDirectory = if ($WorkingDirectory -eq $root) { '%USERPROFILE%' } else { $WorkingDirectory }
                inheritedEnvironment = @(
                    'NONSECRET_CONTEXT',
                    'FAKE_BWS_LOG',
                    'FAKE_BWS_VALUE',
                    'FAKE_BWS_PROJECT',
                    'FAKE_BWS_FAIL'
                )
                projectId = $ProjectId
                secretBindings = @(
                    [ordered]@{
                        secretId = $SecretId
                        environmentVariable = 'INJECTED_VALUE'
                    }
                )
            },
            [ordered]@{
                commandId = 'sibling-command'
                purpose = 'Prove that another command secret is not inherited'
                executable = $powershell
                argumentList = @('-NoProfile')
                workingDirectory = $WorkingDirectory
                projectId = $ProjectId
                secretBindings = @(
                    [ordered]@{
                        secretId = 'sibling-secret'
                        environmentVariable = 'UNRELATED_SECRET'
                    }
                )
            }
        )
    }

    [System.IO.File]::WriteAllText(
        $allowlist,
        ($policy | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Broker {
    param(
        [string]$CommandId = 'docket-sync',
        [string]$PolicyPath = $allowlist
    )

    $plan = Get-BwsCommandPlan -CommandId $CommandId -AllowlistPath $PolicyPath `
        -TrustedUserProfile $root -TrustedProgramFiles $root
    $machineToken = ConvertTo-SecureString $env:FAKE_BWS_TOKEN -AsPlainText -Force
    try {
        Invoke-BwsCommandCore -Plan $plan -BwsPath $mockBws -MachineToken $machineToken
    }
    finally {
        $machineToken.Dispose()
    }
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $mockSource = @'
using System;
using System.IO;

public static class Program
{
    public static int Main(string[] args)
    {
        string log = Environment.GetEnvironmentVariable("FAKE_BWS_LOG");
        if (!String.IsNullOrEmpty(log))
        {
            File.AppendAllText(log, String.Join("|", args) + Environment.NewLine);
        }

        if (Environment.GetEnvironmentVariable("NONSECRET_CONTEXT") != "parent-context")
        {
            Console.Error.Write("missing inherited nonsecret context");
            return 24;
        }
        if (!String.IsNullOrEmpty(Environment.GetEnvironmentVariable("BW_SESSION")) ||
            !String.IsNullOrEmpty(Environment.GetEnvironmentVariable("INJECTED_VALUE")) ||
            !String.IsNullOrEmpty(Environment.GetEnvironmentVariable("UNRELATED_SECRET")) ||
            !String.IsNullOrEmpty(Environment.GetEnvironmentVariable("UNLISTED_PARENT_VALUE")))
        {
            Console.Error.Write("inherited secret destination");
            return 25;
        }

        string token = Environment.GetEnvironmentVariable("BWS_ACCESS_TOKEN");
        if (String.IsNullOrEmpty(token))
        {
            Console.Error.Write("missing bootstrap credential");
            return 21;
        }

        if (Environment.GetEnvironmentVariable("FAKE_BWS_FAIL") == "1")
        {
            Console.Error.Write("failure-" + token + "-" + Environment.GetEnvironmentVariable("FAKE_BWS_VALUE"));
            return 22;
        }

        if (args.Length != 5 || args[0] != "secret" || args[1] != "get" || args[3] != "--output" || args[4] != "json")
        {
            Console.Error.Write("unexpected invocation");
            return 23;
        }

        string value = Environment.GetEnvironmentVariable("FAKE_BWS_VALUE");
        string project = Environment.GetEnvironmentVariable("FAKE_BWS_PROJECT");
        Console.Write("{\"id\":\"" + args[2] + "\",\"projectId\":\"" + project + "\",\"value\":\"" + value + "\"}");
        return 0;
    }
}
'@
    Add-Type -TypeDefinition $mockSource -Language CSharp -OutputAssembly $mockBws -OutputType ConsoleApplication

    [System.IO.File]::WriteAllText(
        $child,
        @'
if ($env:INJECTED_VALUE -ne $env:FAKE_BWS_VALUE) { exit 31 }
if ($env:BWS_ACCESS_TOKEN) { exit 32 }
if ($env:BW_SESSION) { exit 33 }
if ($env:UNRELATED_SECRET) { exit 34 }
if ($env:UNLISTED_PARENT_VALUE) { exit 36 }
if ((Get-Location).Path -ne (Split-Path -Parent $args[0])) { exit 35 }
[System.IO.File]::WriteAllText($args[0], 'ok')
Write-Output ("stdout-" + $env:INJECTED_VALUE)
[Console]::Error.WriteLine("stderr-" + $env:INJECTED_VALUE)
'@,
        [System.Text.UTF8Encoding]::new($false)
    )

    $env:FAKE_BWS_LOG = $invocationLog
    $env:BWS_TEST_ROOT = $root
    $env:FAKE_BWS_TOKEN = 'bootstrap-test-canary'
    $env:FAKE_BWS_VALUE = 'secret-test-canary'
    $env:FAKE_BWS_PROJECT = 'project-unit'
    $env:BWS_ACCESS_TOKEN = 'parent-bootstrap-canary'
    $env:BW_SESSION = 'parent-session-canary'
    $env:UNRELATED_SECRET = 'parent-unrelated-canary'
    $env:UNLISTED_PARENT_VALUE = 'parent-unlisted-canary'
    $env:NONSECRET_CONTEXT = 'parent-context'

    Write-TestPolicy

    $trustedProfile = Join-Path $root 'trusted-profile'
    $trustedProgramFiles = Join-Path $root 'trusted-program-files'
    $trustedTool = Join-Path $trustedProgramFiles 'trusted-tool.exe'
    New-Item -ItemType Directory -Path $trustedProfile, $trustedProgramFiles -Force | Out-Null
    Copy-Item -LiteralPath $powershell -Destination $trustedTool
    $trustedPolicy = Join-Path $root 'trusted-token-policy.json'
    [System.IO.File]::WriteAllText(
        $trustedPolicy,
        (@{
            schemaVersion = 3
            commands = @(@{
                commandId = 'trusted-token-proof'
                executable = '%ProgramFiles%\trusted-tool.exe'
                argumentList = @('%USERPROFILE%\approved-child.ps1')
                workingDirectory = '%USERPROFILE%'
                inheritedEnvironment = @()
                projectId = 'project-unit'
                secretBindings = @(@{
                    secretId = 'secret-unit'
                    environmentVariable = 'INJECTED_VALUE'
                })
            })
        } | ConvertTo-Json -Depth 8),
        [System.Text.UTF8Encoding]::new($false)
    )
    $savedPoisonedEnvironment = @{}
    foreach ($name in @('USERPROFILE', 'ProgramFiles', 'ProgramFiles(x86)', 'ProgramW6432', 'PATH')) {
        $savedPoisonedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, (Join-Path $root "poison-$($name.Replace('(', '').Replace(')', ''))"), 'Process')
    }
    try {
        $trustedPlan = Get-BwsCommandPlan -CommandId 'trusted-token-proof' -AllowlistPath $trustedPolicy `
            -TrustedUserProfile $trustedProfile -TrustedProgramFiles $trustedProgramFiles
        Assert-True ($trustedPlan.Executable -eq $trustedTool) 'A poisoned environment redirected the approved executable.'
        Assert-True ($trustedPlan.WorkingDirectory -eq $trustedProfile) 'A poisoned environment redirected the approved working directory.'
        Assert-True ($trustedPlan.Arguments[0] -eq (Join-Path $trustedProfile 'approved-child.ps1')) 'A poisoned environment redirected an approved argument.'
    }
    finally {
        foreach ($name in $savedPoisonedEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $savedPoisonedEnvironment[$name], 'Process')
        }
    }

    $unknownTokenPolicy = Join-Path $root 'unknown-token-policy.json'
    (Get-Content -Raw -LiteralPath $trustedPolicy).Replace(
        '%ProgramFiles%',
        '%ProgramW6432%'
    ) | Set-Content -LiteralPath $unknownTokenPolicy -Encoding UTF8
    $unknownTokenBlocked = $false
    try {
        Get-BwsCommandPlan -CommandId 'trusted-token-proof' -AllowlistPath $unknownTokenPolicy `
            -TrustedUserProfile $trustedProfile -TrustedProgramFiles $trustedProgramFiles | Out-Null
    }
    catch {
        $unknownTokenBlocked = $_.Exception.Message -match 'unsupported|unresolved|token'
    }
    Assert-True $unknownTokenBlocked 'An unsupported environment token was accepted in the trusted command policy.'

    try {
        $captured = (Invoke-Broker 3>&1 2>&1 | Out-String)
    }
    catch {
        throw ($_.Exception.Message + [Environment]::NewLine + $_.ScriptStackTrace)
    }
    Assert-True (Test-Path -LiteralPath $marker) 'The allowlisted target did not run.'
    Assert-True ($captured -match '\[REDACTED\]') 'The broker did not surface a redaction marker.'
    Assert-True ($captured -notmatch 'secret-test-canary') 'Target output leaked the injected secret.'
    Assert-True ($captured -notmatch 'bootstrap-test-canary') 'Target output leaked the bootstrap credential.'
    Assert-True ($env:BWS_ACCESS_TOKEN -eq 'parent-bootstrap-canary') 'The parent BWS_ACCESS_TOKEN changed.'
    Assert-True ($env:BW_SESSION -eq 'parent-session-canary') 'The parent BW_SESSION changed.'
    Assert-True ($env:UNRELATED_SECRET -eq 'parent-unrelated-canary') 'The parent unrelated variable changed.'

    $bwsCalls = @(Get-Content -LiteralPath $invocationLog)
    Assert-True ($bwsCalls.Count -eq 1) 'The broker fetched an unexpected number of secrets.'
    Assert-True ($bwsCalls[0] -eq 'secret|get|secret-unit|--output|json') 'The broker fetched an unapproved secret ID.'

    $unknownBlocked = $false
    try {
        Invoke-Broker -CommandId 'unknown-command'
    }
    catch {
        $unknownBlocked = $_.Exception.Message -match 'CommandId'
    }
    Assert-True $unknownBlocked 'An unknown CommandId was not rejected.'

    Write-TestPolicy -ProjectId 'different-project'
    $projectBlocked = $false
    try {
        Invoke-Broker
    }
    catch {
        $projectBlocked = $_.Exception.Message -match 'approved Bitwarden project'
        Assert-True ($_.Exception.Message -notmatch 'secret-test-canary|bootstrap-test-canary') 'Project mismatch error leaked a credential.'
    }
    Assert-True $projectBlocked 'A secret from a different Bitwarden project was accepted.'

    $badPolicy = Join-Path $root 'duplicate-command.json'
    [System.IO.File]::WriteAllText(
        $badPolicy,
        '{"schemaVersion":3,"commands":[{"commandId":"same"},{"commandId":"same"}]}',
        [System.Text.UTF8Encoding]::new($false)
    )
    $duplicateBlocked = $false
    try {
        Invoke-Broker -CommandId 'same' -PolicyPath $badPolicy
    }
    catch {
        $duplicateBlocked = $_.Exception.Message -match 'exactly one'
    }
    Assert-True $duplicateBlocked 'Duplicate CommandId records were accepted.'

    Write-TestPolicy
    Remove-Item -LiteralPath $marker -Force
    $env:FAKE_BWS_FAIL = '1'
    $bwsFailureBlocked = $false
    try {
        Invoke-Broker
    }
    catch {
        $bwsFailureBlocked = $_.Exception.Message -match 'could not retrieve'
        Assert-True ($_.Exception.Message -notmatch 'secret-test-canary|bootstrap-test-canary') 'BWS failure output leaked a credential.'
    }
    finally {
        Remove-Item Env:\FAKE_BWS_FAIL -ErrorAction SilentlyContinue
    }
    Assert-True $bwsFailureBlocked 'A failed BWS lookup did not fail closed.'
    Assert-True (-not (Test-Path -LiteralPath $marker)) 'The target ran after a failed BWS lookup.'

    'Bitwarden Secrets Manager broker regression test passed.'
}
finally {
    foreach ($name in @(
        'FAKE_BWS_LOG',
        'BWS_TEST_ROOT',
        'FAKE_BWS_TOKEN',
        'FAKE_BWS_VALUE',
        'FAKE_BWS_PROJECT',
        'FAKE_BWS_FAIL',
        'BWS_ACCESS_TOKEN',
        'BW_SESSION',
        'UNRELATED_SECRET',
        'UNLISTED_PARENT_VALUE',
        'NONSECRET_CONTEXT'
    )) {
        Remove-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
