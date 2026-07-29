[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskName = 'Nightly Agent Backups',
    [string]$BackupCommand,
    [datetime]$At = '02:00'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($BackupCommand)) {
    $BackupCommand = Join-Path $PSScriptRoot 'Backup-AgentWorkspace.cmd'
}

$resolvedCommand = (Resolve-Path -LiteralPath $BackupCommand).Path
$action = New-ScheduledTaskAction -Execute $resolvedCommand
$trigger = New-ScheduledTaskTrigger -Daily -At $At
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 6)

if ($PSCmdlet.ShouldProcess($TaskName, 'Register portable nightly agent backup task')) {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description 'Creates a verified recovery snapshot of agent repositories, approved application data, handoffs, and Quick Access state.' `
        -Force | Out-Null
}

[pscustomobject]@{
    TaskName = $TaskName
    BackupCommand = $resolvedCommand
    Schedule = $At.ToString('HH:mm')
    StartWhenAvailable = $true
    RunsOnBattery = $true
    StopsOnBattery = $false
}
