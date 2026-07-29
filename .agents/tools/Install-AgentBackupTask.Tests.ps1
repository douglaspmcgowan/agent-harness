$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Install-AgentBackupTask.ps1'
$text = Get-Content -LiteralPath $scriptPath -Raw

$required = @(
    'New-ScheduledTaskTrigger -Daily',
    '-AllowStartIfOnBatteries',
    '-DontStopIfGoingOnBatteries',
    '-StartWhenAvailable',
    '-MultipleInstances IgnoreNew',
    '-LogonType Interactive',
    '-RunLevel Limited'
)

foreach ($token in $required) {
    if ($text.IndexOf($token, [StringComparison]::Ordinal) -lt 0) {
        throw "Missing portable backup-task invariant: $token"
    }
}

if ($text -match '(?i)password|token|secret') {
    $allowedDescription = 'approved application data'
    if ($text -notmatch [regex]::Escape($allowedDescription)) {
        throw 'Task installer contains unexpected credential-shaped text.'
    }
}

'Agent backup task installer tests passed.'
