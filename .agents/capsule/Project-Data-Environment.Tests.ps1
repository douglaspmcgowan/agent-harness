[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$subject = Join-Path $PSScriptRoot 'Set-ProjectDataEnvironment.ps1'
$testRoot = Join-Path $env:TEMP ('project-data-environment-test-' + [Guid]::NewGuid().ToString('N'))

try {
    $userRoot = Join-Path $testRoot 'Receiving User With Spaces'
    $myDrive = Join-Path $testRoot 'Google Drive With Spaces\My Drive'
    New-Item -ItemType Directory -Path $userRoot, $myDrive -Force | Out-Null

    $state = @{
        PROJECT_DATA_SYNC_ROOT = 'C:\Users\Old\OneDrive\Project Data'
        PROJECT_DATA_ROOT = 'C:\Missing\Projects'
    }
    $writes = [System.Collections.Generic.List[object]]::new()
    $read = {
        param($Name)
        return $state[$Name]
    }.GetNewClosure()
    $write = {
        param($Name, $Value, $ExpandedValue)
        $writes.Add([pscustomobject]@{
            Name = $Name
            Value = $Value
            ExpandedValue = $ExpandedValue
        })
        $state[$Name] = $Value
    }.GetNewClosure()

    $dryRun = & $subject `
        -UserRoot $userRoot `
        -GoogleDriveMyDriveRoot $myDrive `
        -ReadUserEnvironment $read `
        -WriteUserEnvironment $write
    if ($dryRun.Mode -ne 'DRY-RUN' -or $writes.Count -ne 0) {
        throw 'Project-data environment dry run mutated the user environment.'
    }
    if (Test-Path -LiteralPath (Join-Path $myDrive 'Project Data')) {
        throw 'Project-data environment dry run created the synchronized data folder.'
    }
    if ($dryRun.ProjectDataSyncRoot -ne (Join-Path $myDrive 'Project Data') -or
        $dryRun.ProjectDataRoot -ne '%USERPROFILE%\Data\Projects') {
        throw 'Project-data environment dry run returned the wrong target values.'
    }

    $applied = & $subject `
        -UserRoot $userRoot `
        -GoogleDriveMyDriveRoot $myDrive `
        -ReadUserEnvironment $read `
        -WriteUserEnvironment $write `
        -Apply
    if ($applied.Mode -ne 'APPLY' -or $writes.Count -ne 2) {
        throw "Project-data environment apply wrote the wrong number of variables: $($writes.Count)"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $myDrive 'Project Data') -PathType Container)) {
        throw 'Project-data environment apply did not create the synchronized data folder.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $userRoot 'Data\Projects') -PathType Container)) {
        throw 'Project-data environment apply did not create the local project-data folder.'
    }
    if ($state.PROJECT_DATA_SYNC_ROOT -ne (Join-Path $myDrive 'Project Data') -or
        $state.PROJECT_DATA_ROOT -ne '%USERPROFILE%\Data\Projects') {
        throw 'Project-data environment apply wrote the wrong values.'
    }
    $localWrite = @($writes | Where-Object Name -eq 'PROJECT_DATA_ROOT')
    if ($localWrite.Count -ne 1 -or
        $localWrite[0].ExpandedValue -ne (Join-Path $userRoot 'Data\Projects')) {
        throw 'PROJECT_DATA_ROOT did not preserve its portable value and receiving-profile expansion.'
    }

    $validLocal = Join-Path $userRoot 'Existing Project Data'
    $validSync = Join-Path $myDrive 'Existing Synced Data'
    New-Item -ItemType Directory -Path $validLocal, $validSync -Force | Out-Null
    $preservedState = @{
        PROJECT_DATA_SYNC_ROOT = $validSync
        PROJECT_DATA_ROOT = $validLocal
    }
    $preservedWrites = [System.Collections.Generic.List[object]]::new()
    $preservedRead = {
        param($Name)
        return $preservedState[$Name]
    }.GetNewClosure()
    $preservedWrite = {
        param($Name, $Value, $ExpandedValue)
        $preservedWrites.Add([pscustomobject]@{ Name = $Name; Value = $Value })
    }.GetNewClosure()
    $preserved = & $subject `
        -UserRoot $userRoot `
        -GoogleDriveMyDriveRoot $myDrive `
        -ReadUserEnvironment $preservedRead `
        -WriteUserEnvironment $preservedWrite `
        -Apply
    if ($preservedWrites.Count -ne 0 -or
        $preserved.ProjectDataSyncRoot -ne $validSync -or
        $preserved.ProjectDataRoot -ne $validLocal) {
        throw 'Project-data environment apply replaced valid existing values.'
    }

    $retiredOrganizationRoot = Join-Path $testRoot 'OneDrive - Example Organization'
    $retiredSync = Join-Path $retiredOrganizationRoot 'Project Data'
    $retiredLocal = Join-Path $retiredOrganizationRoot 'Local Projects'
    New-Item -ItemType Directory -Path $retiredSync, $retiredLocal -Force | Out-Null
    $organizationState = @{
        PROJECT_DATA_SYNC_ROOT = $retiredSync
        PROJECT_DATA_ROOT = $retiredLocal
    }
    $organizationWrites = [System.Collections.Generic.List[object]]::new()
    $organizationRead = {
        param($Name)
        return $organizationState[$Name]
    }.GetNewClosure()
    $organizationWrite = {
        param($Name, $Value, $ExpandedValue)
        $organizationWrites.Add([pscustomobject]@{ Name = $Name; Value = $Value })
        $organizationState[$Name] = $Value
    }.GetNewClosure()
    & $subject `
        -UserRoot $userRoot `
        -GoogleDriveMyDriveRoot $myDrive `
        -ReadUserEnvironment $organizationRead `
        -WriteUserEnvironment $organizationWrite `
        -Apply | Out-Null
    if ($organizationWrites.Count -ne 2 -or
        $organizationState.PROJECT_DATA_SYNC_ROOT -ne (Join-Path $myDrive 'Project Data') -or
        $organizationState.PROJECT_DATA_ROOT -ne '%USERPROFILE%\Data\Projects') {
        throw 'Project-data environment preserved a retired OneDrive - Organization path.'
    }

    [pscustomobject]@{
        Result = 'PASS'
        DryRunNoMutation = $true
        ApplyCreatesSyncFolder = $true
        ApplyCreatesLocalFolder = $true
        PortableLocalValue = $true
        ValidExistingValuesPreserved = $true
        OrganizationOneDriveRetired = $true
        PathWithSpaces = $true
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
