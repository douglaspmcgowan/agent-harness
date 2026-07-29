[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$UserPathOverride,

    [string]$MachinePathOverride,

    [string]$ProcessPathOverride,

    [string[]]$AdditionalUserPathDirectory = @(),

    [switch]$SkipStandardDirectories,

    [switch]$SkipFreshProcessVerification,

    [switch]$ApplyUserPath
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedPathEntries {
    param(
        [AllowEmptyString()]
        [string]$PathValue
    )

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $entries = [Collections.Generic.List[string]]::new()
    foreach ($entry in @($PathValue -split ';')) {
        $trimmed = [Environment]::ExpandEnvironmentVariables([string]$entry).Trim().TrimEnd('\')
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($seen.Add($trimmed)) {
            [void]$entries.Add($trimmed)
        }
    }
    $entries.ToArray()
}

function Get-HighestSupabaseDirectory {
    param(
        [string]$SupabaseRoot
    )

    if (-not (Test-Path -LiteralPath $SupabaseRoot -PathType Container)) {
        return $null
    }

    @(
        Get-ChildItem -LiteralPath $SupabaseRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'supabase.exe') -PathType Leaf } |
            ForEach-Object {
                $parsed = [version]'0.0'
                [void][version]::TryParse($_.Name, [ref]$parsed)
                [pscustomobject]@{ Directory = $_.FullName; Version = $parsed }
            } |
            Sort-Object Version -Descending |
            Select-Object -First 1
    ).Directory
}

function Resolve-CommandsForPath {
    param(
        [string]$PathValue,
        [string[]]$Names
    )

    $priorPath = $env:Path
    try {
        $env:Path = $PathValue
        @(
            foreach ($name in $Names) {
                $matches = @(
                    Get-Command $name -All -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.Source } |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                        Where-Object {
                            if ($name -notin @('python', 'py', 'dvc')) {
                                return $true
                            }
                            $priorPreference = $ErrorActionPreference
                            try {
                                $ErrorActionPreference = 'Continue'
                                if ($name -eq 'python') {
                                    & $_ -c 'import sqlite3,sys; sys.exit(0)' 2>&1 | Out-Null
                                }
                                elseif ($name -eq 'py') {
                                    & $_ -3 -c 'import sqlite3,sys; sys.exit(0)' 2>&1 | Out-Null
                                }
                                else {
                                    & $_ --version 2>&1 | Out-Null
                                }
                                return $LASTEXITCODE -eq 0
                            }
                            catch {
                                return $false
                            }
                            finally {
                                $ErrorActionPreference = $priorPreference
                            }
                        } |
                        Select-Object -Unique
                )
                [pscustomobject]@{
                    name = $name
                    matches = $matches
                    primary = if ($matches.Count -gt 0) { $matches[0] } else { $null }
                }
            }
        )
    }
    finally {
        $env:Path = $priorPath
    }
}

function Invoke-FreshResolution {
    param(
        [string]$PathValue,
        [string[]]$Names
    )

    $prior = [Environment]::GetEnvironmentVariable('AGENT_EXEC_DISCOVERY_PATH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('AGENT_EXEC_DISCOVERY_PATH', $PathValue, 'Process')
        $nameLiteral = ($Names | ForEach-Object { "'$($_.Replace("'", "''"))'" }) -join ','
        $scriptText = @"
`$env:Path = `$env:AGENT_EXEC_DISCOVERY_PATH
`$names = @($nameLiteral)
`$rows = @(
    foreach (`$name in `$names) {
        `$matches = @(Get-Command `$name -All -ErrorAction SilentlyContinue)
        if (`$name -in @('python', 'py', 'dvc')) {
            `$matches = @(`$matches | Where-Object {
                `$priorPreference = `$ErrorActionPreference
                try {
                    `$ErrorActionPreference = 'Continue'
                    if (`$name -eq 'python') {
                        & `$_.Source -c 'import sqlite3,sys; sys.exit(0)' 2>&1 | Out-Null
                    }
                    elseif (`$name -eq 'py') {
                        & `$_.Source -3 -c 'import sqlite3,sys; sys.exit(0)' 2>&1 | Out-Null
                    }
                    else {
                        & `$_.Source --version 2>&1 | Out-Null
                    }
                    `$LASTEXITCODE -eq 0
                }
                catch { `$false }
                finally { `$ErrorActionPreference = `$priorPreference }
            })
        }
        `$match = `$matches | Select-Object -First 1
        [pscustomobject]@{
            name = `$name
            primary = if (`$match) { `$match.Source } else { `$null }
        }
    }
)
`$rows | ConvertTo-Json -Compress
"@
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText))
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded 2>&1
        if ($LASTEXITCODE -ne 0) {
            return [pscustomobject]@{
                status = 'SKIP'
                reason = 'A fresh PowerShell process could not complete command discovery.'
                commands = @()
            }
        }
        $parsedCommands = [object[]](
            ([string]::Join([Environment]::NewLine, @($output))) | ConvertFrom-Json
        )
        [pscustomobject]@{
            status = 'PASS'
            reason = $null
            commands = $parsedCommands
        }
    }
    finally {
        [Environment]::SetEnvironmentVariable('AGENT_EXEC_DISCOVERY_PATH', $prior, 'Process')
    }
}

function Send-EnvironmentChanged {
    if (-not ([System.Management.Automation.PSTypeName]'AgentHarness.EnvironmentBroadcast').Type) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace AgentHarness
{
    public static class EnvironmentBroadcast
    {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            UInt32 message,
            UIntPtr wParam,
            string lParam,
            UInt32 flags,
            UInt32 timeout,
            out UIntPtr result
        );
    }
}
'@ | Out-Null
    }
    $result = [UIntPtr]::Zero
    [void][AgentHarness.EnvironmentBroadcast]::SendMessageTimeout(
        [IntPtr]0xffff,
        0x001A,
        [UIntPtr]::Zero,
        'Environment',
        2,
        5000,
        [ref]$result
    )
}

$userPath = if ($PSBoundParameters.ContainsKey('UserPathOverride')) {
    $UserPathOverride
}
else {
    [Environment]::GetEnvironmentVariable('Path', 'User')
}
$machinePath = if ($PSBoundParameters.ContainsKey('MachinePathOverride')) {
    $MachinePathOverride
}
else {
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
}
$processPath = if ($PSBoundParameters.ContainsKey('ProcessPathOverride')) {
    $ProcessPathOverride
}
else {
    $env:Path
}

$userEntries = @(Get-NormalizedPathEntries -PathValue $userPath)
$machineEntries = @(Get-NormalizedPathEntries -PathValue $machinePath)
$processEntries = @(Get-NormalizedPathEntries -PathValue $processPath)

$standardDirectories = [Collections.Generic.List[string]]::new()
if (-not $SkipStandardDirectories) {
    $pythonRoot = Join-Path $env:USERPROFILE 'AppData\Local\Programs\Python\Python312'
    $pythonScripts = Join-Path $pythonRoot 'Scripts'
    $pythonLauncher = Join-Path $env:USERPROFILE 'AppData\Local\Programs\Python\Launcher'
    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    $bwsDirectory = Join-Path $env:USERPROFILE 'Tools\bws'
    $gitleaksDirectory = Join-Path $env:USERPROFILE 'Tools\gitleaks'
    $installedHarnessTools = Join-Path $env:USERPROFILE '.agents\tools'
    $supabaseDirectory = Get-HighestSupabaseDirectory -SupabaseRoot (
        Join-Path $env:USERPROFILE 'Tools\Supabase'
    )

    foreach ($candidate in @(
        $pythonRoot,
        $pythonScripts,
        $pythonLauncher,
        $localBin,
        $bwsDirectory,
        $gitleaksDirectory,
        $supabaseDirectory,
        $installedHarnessTools
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and
            (Test-Path -LiteralPath $candidate -PathType Container)) {
            [void]$standardDirectories.Add([System.IO.Path]::GetFullPath($candidate).TrimEnd('\'))
        }
    }
}
foreach ($candidate in $AdditionalUserPathDirectory) {
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        throw "Additional executable directory does not exist: $candidate"
    }
    [void]$standardDirectories.Add([System.IO.Path]::GetFullPath($candidate).TrimEnd('\'))
}

$knownPersistent = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in @($machineEntries + $userEntries)) {
    [void]$knownPersistent.Add($entry)
}
$pathAdded = @(
    $standardDirectories |
        Where-Object { -not $knownPersistent.Contains($_) } |
        Select-Object -Unique
)

$recommendedEntries = [Collections.Generic.List[string]]::new()
$recommendedSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in @($pathAdded + $userEntries)) {
    if ($recommendedSeen.Add($entry)) {
        [void]$recommendedEntries.Add($entry)
    }
}
$recommendedUserPath = $recommendedEntries -join ';'
$normalizedOriginalUserPath = $userEntries -join ';'
$userPathChanged = -not [string]::Equals(
    $normalizedOriginalUserPath,
    $recommendedUserPath,
    [StringComparison]::OrdinalIgnoreCase
) -or @($userPath -split ';' | Where-Object { $_ }).Count -ne $userEntries.Count

if ($ApplyUserPath -and $userPathChanged -and
    $PSCmdlet.ShouldProcess('User PATH', 'Preserve, deduplicate, and prepend installed executable directories')) {
    if ($PSBoundParameters.ContainsKey('UserPathOverride')) {
        throw 'UserPathOverride cannot be combined with a live User PATH mutation.'
    }
    [Environment]::SetEnvironmentVariable('Path', $recommendedUserPath, 'User')
    Send-EnvironmentChanged
}

$commandNames = @(
    'git',
    'gh',
    'node',
    'npm',
    'npx',
    'python',
    'py',
    'pip',
    'powershell',
    'pwsh',
    'bws',
    'supabase',
    'vercel',
    'dvc',
    'gitleaks'
)
$persistentPath = (@($machineEntries + $recommendedEntries) -join ';')
$processResolution = @(Resolve-CommandsForPath -PathValue $processPath -Names $commandNames)
$persistentResolution = @(Resolve-CommandsForPath -PathValue $persistentPath -Names $commandNames)
$toolRows = @(
    foreach ($name in $commandNames) {
        $current = @($processResolution | Where-Object name -eq $name)[0]
        $persistent = @($persistentResolution | Where-Object name -eq $name)[0]
        [pscustomobject]@{
            name = $name
            processPrimary = $current.primary
            processMatches = @($current.matches)
            persistentPrimary = $persistent.primary
            persistentMatches = @($persistent.matches)
            availableAfterNormalization = -not [string]::IsNullOrWhiteSpace($persistent.primary)
        }
    }
)

$fresh = if ($SkipFreshProcessVerification) {
    [pscustomobject]@{
        status = 'SKIP'
        reason = 'Fresh-process verification was explicitly skipped.'
        commands = @()
    }
}
else {
    Invoke-FreshResolution -PathValue $persistentPath -Names $commandNames
}

$driveRoot = 'C:\Program Files\Google\Drive File Stream'
$driveExecutables = @(
    if (Test-Path -LiteralPath $driveRoot -PathType Container) {
        Get-ChildItem -LiteralPath $driveRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
            ForEach-Object {
                $executable = Join-Path $_.FullName 'GoogleDriveFS.exe'
                if (Test-Path -LiteralPath $executable -PathType Leaf) {
                    [pscustomobject]@{
                        version = $_.Name
                        executable = $executable
                    }
                }
            } |
            Sort-Object { [version]$_.version } -Descending
    }
)

$pathRows = @(
    foreach ($scope in @(
        [pscustomobject]@{ Name = 'User'; Entries = $userEntries },
        [pscustomobject]@{ Name = 'Machine'; Entries = $machineEntries },
        [pscustomobject]@{ Name = 'Process'; Entries = $processEntries }
    )) {
        foreach ($entry in $scope.Entries) {
            [pscustomobject]@{
                scope = $scope.Name
                path = $entry
                exists = Test-Path -LiteralPath $entry -PathType Container
            }
        }
    }
)

$installedHarnessTools = Join-Path $env:USERPROFILE '.agents\tools'
[pscustomobject]@{
    userPathBefore = $userPath
    recommendedUserPath = $recommendedUserPath
    userPathChanged = $userPathChanged
    pathAdded = @($pathAdded)
    pathEntries = $pathRows
    tools = $toolRows
    freshProcess = $fresh
    googleDrive = [pscustomobject]@{
        installed = $driveExecutables.Count -gt 0
        current = if ($driveExecutables.Count -gt 0) { $driveExecutables[0] } else { $null }
        versions = $driveExecutables
    }
    harnessTools = [pscustomobject]@{
        path = $installedHarnessTools
        sourcePath = $PSScriptRoot
        installed = Test-Path -LiteralPath $installedHarnessTools -PathType Container
        cmdCount = @(
            Get-ChildItem -LiteralPath $installedHarnessTools -Filter '*.cmd' -File -ErrorAction SilentlyContinue
        ).Count
        ps1Count = @(
            Get-ChildItem -LiteralPath $installedHarnessTools -Filter '*.ps1' -File -ErrorAction SilentlyContinue
        ).Count
    }
}
