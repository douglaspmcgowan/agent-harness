[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$TaskName = 'Stale Agent Process Cleanup',
    [string]$CleanupScript,
    [ValidateRange(30, 10080)]
    [int]$MinimumAgeMinutes = 180,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

if (-not $CleanupScript) {
    $CleanupScript = Join-Path $PSScriptRoot 'Clear-StaleAgentProcesses.ps1'
}
if (-not $LogPath) {
    $LogPath = Join-Path $env:USERPROFILE '.agents\logs\stale-agent-process-cleanup.jsonl'
}

if (-not (Test-Path -LiteralPath $CleanupScript -PathType Leaf)) {
    throw "Cleanup script is unavailable: $CleanupScript"
}

$powerShellPath = (Get-Command powershell.exe -CommandType Application).Source
$arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', "`"$CleanupScript`"",
    '-Execute',
    '-MinimumAgeMinutes', $MinimumAgeMinutes,
    '-LogPath', "`"$LogPath`""
) -join ' '

$action = New-ScheduledTaskAction -Execute $powerShellPath -Argument $arguments
$triggers = @(
    New-ScheduledTaskTrigger -Daily -At '1:15 AM'
    New-ScheduledTaskTrigger -Daily -At '7:15 AM'
    New-ScheduledTaskTrigger -Daily -At '1:15 PM'
    New-ScheduledTaskTrigger -Daily -At '7:15 PM'
)
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15) `
    -MultipleInstances IgnoreNew
$userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited

if ($PSCmdlet.ShouldProcess($TaskName, 'Register guarded stale-agent-process cleanup task')) {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $triggers `
        -Settings $settings `
        -Principal $principal `
        -Description 'Removes only old orphaned node-cmd-node agent helper trees after active-agent exclusions and immediate revalidation.' `
        -Force | Out-Null
}

[pscustomobject]@{
    TaskName = $TaskName
    UserId = $userId
    CleanupScript = $CleanupScript
    MinimumAgeMinutes = $MinimumAgeMinutes
    LogPath = $LogPath
    TriggerTimes = @('01:15', '07:15', '13:15', '19:15')
    Installed = [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
}
