[CmdletBinding()]
param(
    [string]$UserRoot = $env:USERPROFILE,
    [string]$GoogleDriveMyDriveRoot,
    [string[]]$GoogleDriveCandidates,
    [scriptblock]$ReadUserEnvironment,
    [scriptblock]$WriteUserEnvironment,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$UserRoot = [System.IO.Path]::GetFullPath($UserRoot)
$retiredSyncPattern = '(?i)(^|[\\/])OneDrive(?:\s*-\s*[^\\/]+)?([\\/]|$)'

function Resolve-EnvironmentPath {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $expanded = $Value.Replace('%USERPROFILE%', $UserRoot).Replace('%userprofile%', $UserRoot)
    return [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($expanded))
}

function Test-CurrentProjectDataPath {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match $retiredSyncPattern) {
        return $false
    }
    try {
        $expanded = Resolve-EnvironmentPath -Value $Value
        return Test-Path -LiteralPath $expanded -PathType Container
    }
    catch {
        return $false
    }
}

if (-not $ReadUserEnvironment) {
    $ReadUserEnvironment = {
        param($Name)
        return [Environment]::GetEnvironmentVariable($Name, 'User')
    }
}
if (-not $WriteUserEnvironment) {
    $WriteUserEnvironment = {
        param($Name, $Value, $ExpandedValue)

        $environmentKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        if (-not $environmentKey) {
            throw 'The current user Environment registry key is unavailable.'
        }
        try {
            $environmentKey.SetValue(
                $Name,
                $Value,
                [Microsoft.Win32.RegistryValueKind]::ExpandString
            )
        }
        finally {
            $environmentKey.Dispose()
        }
        [Environment]::SetEnvironmentVariable($Name, $ExpandedValue, 'Process')
    }
}

$existingSyncValue = [string](& $ReadUserEnvironment 'PROJECT_DATA_SYNC_ROOT')
$existingLocalValue = [string](& $ReadUserEnvironment 'PROJECT_DATA_ROOT')

if ($GoogleDriveMyDriveRoot) {
    $GoogleDriveMyDriveRoot = [System.IO.Path]::GetFullPath($GoogleDriveMyDriveRoot)
    if ($GoogleDriveMyDriveRoot -match $retiredSyncPattern -or
        -not [string]::Equals(
            (Split-Path -Leaf $GoogleDriveMyDriveRoot),
            'My Drive',
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Test-Path -LiteralPath $GoogleDriveMyDriveRoot -PathType Container)) {
        throw "Google Drive My Drive root is unavailable or retired: $GoogleDriveMyDriveRoot"
    }
}
else {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($GoogleDriveCandidates) {
        foreach ($candidate in $GoogleDriveCandidates) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $candidates.Add($candidate)
            }
        }
    }
    else {
        $candidates.Add((Join-Path $UserRoot 'My Drive'))
        foreach ($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            if ($drive.Root) {
                $candidates.Add((Join-Path $drive.Root 'My Drive'))
            }
        }
    }

    if (Test-CurrentProjectDataPath -Value $existingSyncValue) {
        $existingSyncRoot = Resolve-EnvironmentPath -Value $existingSyncValue
        $existingParent = Split-Path -Parent $existingSyncRoot
        if ([string]::Equals(
            (Split-Path -Leaf $existingParent),
            'My Drive',
            [StringComparison]::OrdinalIgnoreCase
        )) {
            $candidates.Add($existingParent)
        }
    }

    $available = @($candidates |
        ForEach-Object {
            try {
                $full = [System.IO.Path]::GetFullPath($_)
                if ($full -notmatch $retiredSyncPattern -and
                    [string]::Equals(
                        (Split-Path -Leaf $full),
                        'My Drive',
                        [StringComparison]::OrdinalIgnoreCase
                    ) -and
                    (Test-Path -LiteralPath $full -PathType Container)) {
                    $full
                }
            }
            catch {
            }
        } |
        Sort-Object -Unique)
    if ($available.Count -ne 1) {
        throw "Expected exactly one Google Drive My Drive root; found $($available.Count)."
    }
    $GoogleDriveMyDriveRoot = $available[0]
}

$defaultSyncValue = Join-Path $GoogleDriveMyDriveRoot 'Project Data'
$defaultLocalValue = '%USERPROFILE%\Data\Projects'
$defaultLocalExpanded = Join-Path $UserRoot 'Data\Projects'

$preserveSync = Test-CurrentProjectDataPath -Value $existingSyncValue
$preserveLocal = Test-CurrentProjectDataPath -Value $existingLocalValue
$syncValue = if ($preserveSync) { $existingSyncValue } else { $defaultSyncValue }
$syncExpanded = Resolve-EnvironmentPath -Value $syncValue
$localValue = if ($preserveLocal) { $existingLocalValue } else { $defaultLocalValue }
$localExpanded = if ($preserveLocal) {
    Resolve-EnvironmentPath -Value $existingLocalValue
}
else {
    $defaultLocalExpanded
}

$changed = [System.Collections.Generic.List[string]]::new()
if ($Apply) {
    if (-not (Test-Path -LiteralPath $syncExpanded -PathType Container)) {
        New-Item -ItemType Directory -Path $syncExpanded -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $localExpanded -PathType Container)) {
        New-Item -ItemType Directory -Path $localExpanded -Force | Out-Null
    }
    if (-not $preserveSync) {
        & $WriteUserEnvironment 'PROJECT_DATA_SYNC_ROOT' $syncValue $syncExpanded
        $changed.Add('PROJECT_DATA_SYNC_ROOT')
    }
    if (-not $preserveLocal) {
        & $WriteUserEnvironment 'PROJECT_DATA_ROOT' $localValue $localExpanded
        $changed.Add('PROJECT_DATA_ROOT')
    }

    foreach ($expected in @(
        [pscustomobject]@{ Name = 'PROJECT_DATA_SYNC_ROOT'; Value = $syncValue; Expanded = $syncExpanded },
        [pscustomobject]@{ Name = 'PROJECT_DATA_ROOT'; Value = $localValue; Expanded = $localExpanded }
    )) {
        $actual = [string](& $ReadUserEnvironment $expected.Name)
        if ([string]::IsNullOrWhiteSpace($actual) -or
            -not [string]::Equals(
                (Resolve-EnvironmentPath -Value $actual),
                $expected.Expanded,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw "User environment verification failed for $($expected.Name)."
        }
    }
}

[pscustomobject]@{
    Result = 'PASS'
    Mode = if ($Apply) { 'APPLY' } else { 'DRY-RUN' }
    GoogleDriveMyDriveRoot = $GoogleDriveMyDriveRoot
    ProjectDataSyncRoot = $syncValue
    ProjectDataRoot = $localValue
    ProjectDataRootExpanded = $localExpanded
    PreservedSyncRoot = $preserveSync
    PreservedLocalRoot = $preserveLocal
    ChangedVariables = @($changed)
}
