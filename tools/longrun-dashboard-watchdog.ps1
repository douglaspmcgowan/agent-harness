# Persistent supervisor for the longrun dashboard (port 8756).
#
# Task Scheduler is blocked by Group Policy on this machine (verified 2026-07-02 for the
# SentinelOne monitor: Register-ScheduledTask and schtasks.exe both returned Access Denied),
# and native WSH/VBScript is also blocked (cscript throws the disabled-WSH error), so there
# is no OS-level recurring-task mechanism available. This script IS the supervisor instead:
# launched once, hidden, at logon, it loops for the rest of the session and relaunches the
# dashboard whenever port 8756 stops listening. The prior approach (a Startup-folder .bat
# that checked the port once and exited) only ever recovered the dashboard across a reboot;
# a mid-session stop (e.g. 2026-07-04: repeated preview-tool restarts left it down) had
# nothing watching to bring it back until the next logon.
#
# A named Mutex makes this idempotent: if a watchdog is already running, a second launch
# (e.g. a duplicate logon script run, or a manual re-launch while testing) exits immediately
# instead of running two supervisors. The mutex is owned only while the process is alive --
# Windows releases/destroys the named object automatically when the owning process exits,
# so a crashed or killed watchdog never leaves a stale lock behind.

$mutexName = "Global\ClaudeCode-LongrunDashboard-Watchdog"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    exit
}

$pythonw = "C:\Users\dmcgowa2\scoop\apps\python313\current\pythonw.exe"
$script  = "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py"
$port    = 8756
$intervalSeconds = 60
$logPath = "C:\Users\dmcgowa2\.claude\tools\.watchdog.log"

function Write-WatchdogLog($msg) {
    try {
        $line = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + " " + $msg
        Add-Content -Path $logPath -Value $line -ErrorAction SilentlyContinue
    } catch { }
}

function Test-DashboardUp {
    # Port-open is necessary but not sufficient (found live 2026-07-06: Douglas asked for a real
    # "connected, functional, and working" signal, not just "is a socket open") -- a genuine HTTP
    # GET is what the dashboard's OWN /api/servers health check now does too, so the watchdog
    # holds itself to the same bar it enforces on everything else.
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$port/" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

Write-WatchdogLog "watchdog started (pid $PID)"

# The loop body is wrapped in try/catch so a single transient failure (a WMI hiccup, a momentary
# network-stack error, Start-Process throwing) can NEVER silently kill the whole supervisor --
# found live 2026-07-06: an earlier version with no error handling at all was found dead with no
# diagnostic, and the watchdog's entire purpose is defeated if it can die as easily as the thing
# it's supposed to be more reliable than.
while ($true) {
    try {
        if (-not (Test-DashboardUp)) {
            Write-WatchdogLog "dashboard down, relaunching"
            Start-Process -FilePath $pythonw -ArgumentList @($script, '--port', $port) -WindowStyle Hidden
        }
    } catch {
        Write-WatchdogLog ("check/relaunch error (continuing anyway): " + $_.Exception.Message)
    }
    Start-Sleep -Seconds $intervalSeconds
}
