[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('list', 'create', 'open', 'status', 'merge', 'remove')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [string]$Task,

    [ValidateSet('claude', 'codex', 'cursor')]
    [string]$Agent,

    [string]$BaseRef = 'HEAD',

    [string]$TargetBranch,

    [string]$ManualRoot = 'C:\Users\dougl\Worktrees'
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & git -C $WorkingDirectory @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($exitCode -ne 0) {
        throw ($output -join [Environment]::NewLine)
    }
    return $output
}

function Get-RepositoryRoot {
    param([string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    return (Invoke-Git -WorkingDirectory $resolved rev-parse --show-toplevel | Select-Object -First 1).Trim()
}

function Get-TaskState {
    param(
        [string]$Root,
        [string]$TaskName
    )

    if ([string]::IsNullOrWhiteSpace($TaskName)) {
        throw 'Task is required for this action.'
    }
    if ($TaskName -notmatch '^[a-z0-9][a-z0-9._-]*$') {
        throw 'Task must use lowercase letters, numbers, dots, underscores, or hyphens.'
    }

    $repoName = Split-Path -Leaf $Root
    $path = Join-Path (Join-Path $ManualRoot $repoName) $TaskName
    $branch = "agent/$TaskName"
    return @{
        Path = $path
        Branch = $branch
        RepositoryName = $repoName
    }
}

$repoRoot = Get-RepositoryRoot -Path $Repository

if ($Action -eq 'list') {
    Invoke-Git -WorkingDirectory $repoRoot worktree list --porcelain
    exit 0
}

$taskState = Get-TaskState -Root $repoRoot -TaskName $Task
$worktreePath = $taskState.Path
$branchName = $taskState.Branch

switch ($Action) {
    'create' {
        if (Test-Path -LiteralPath $worktreePath) {
            throw "Worktree path already exists: $worktreePath"
        }
        if (@(Invoke-Git -WorkingDirectory $repoRoot status --porcelain).Count -gt 0) {
            throw 'Stable checkout is dirty. Checkpoint or hand off its changes before creating a manual worktree.'
        }

        $parent = Split-Path -Parent $worktreePath
        New-Item -ItemType Directory -Path $parent -Force | Out-Null

        & git -C $repoRoot show-ref --verify --quiet "refs/heads/$branchName"
        $branchExists = $LASTEXITCODE -eq 0
        if ($branchExists) {
            Invoke-Git -WorkingDirectory $repoRoot worktree add $worktreePath $branchName | Out-Null
        }
        else {
            Invoke-Git -WorkingDirectory $repoRoot worktree add $worktreePath -b $branchName $BaseRef | Out-Null
        }

        "WORKTREE=$worktreePath"
        "BRANCH=$branchName"
        "BASE=$BaseRef"
    }

    'open' {
        if (-not (Test-Path -LiteralPath $worktreePath)) {
            throw "Worktree does not exist: $worktreePath"
        }
        if ([string]::IsNullOrWhiteSpace($Agent)) {
            throw 'Agent is required for open.'
        }

        switch ($Agent) {
            'claude' {
                $command = (Get-Command claude -ErrorAction Stop).Source
                Start-Process -FilePath $command -WorkingDirectory $worktreePath
            }
            'codex' {
                $command = (Get-Command codex -ErrorAction Stop).Source
                Start-Process -FilePath $command -WorkingDirectory $worktreePath
            }
            'cursor' {
                $command = (Get-Command cursor -ErrorAction Stop).Source
                Start-Process -FilePath $command -ArgumentList @($worktreePath) -WorkingDirectory $worktreePath
            }
        }

        "OPENED=$Agent"
        "WORKTREE=$worktreePath"
    }

    'status' {
        if (-not (Test-Path -LiteralPath $worktreePath)) {
            throw "Worktree does not exist: $worktreePath"
        }
        "WORKTREE=$worktreePath"
        "BRANCH=$((Invoke-Git -WorkingDirectory $worktreePath branch --show-current | Select-Object -First 1).Trim())"
        Invoke-Git -WorkingDirectory $worktreePath status --short
    }

    'merge' {
        if (-not (Test-Path -LiteralPath $worktreePath)) {
            throw "Worktree does not exist: $worktreePath"
        }
        if ([string]::IsNullOrWhiteSpace($TargetBranch)) {
            throw 'TargetBranch is required for merge.'
        }
        if (@(Invoke-Git -WorkingDirectory $worktreePath status --porcelain).Count -gt 0) {
            throw 'Source worktree is dirty. Commit or hand off its changes before merge.'
        }
        $sourceBranch = (Invoke-Git -WorkingDirectory $worktreePath branch --show-current | Select-Object -First 1).Trim()
        if ($sourceBranch -ne $branchName) {
            throw "Source worktree is on '$sourceBranch'; expected '$branchName'."
        }
        if (@(Invoke-Git -WorkingDirectory $repoRoot status --porcelain).Count -gt 0) {
            throw 'Stable checkout is dirty. Resolve or checkpoint it before merge.'
        }

        $currentBranch = (Invoke-Git -WorkingDirectory $repoRoot branch --show-current | Select-Object -First 1).Trim()
        if ($currentBranch -ne $TargetBranch) {
            throw "Stable checkout is on '$currentBranch'; expected '$TargetBranch'."
        }

        Invoke-Git -WorkingDirectory $repoRoot merge --no-ff $branchName
    }

    'remove' {
        if (-not (Test-Path -LiteralPath $worktreePath)) {
            throw "Worktree does not exist: $worktreePath"
        }
        if ([string]::IsNullOrWhiteSpace($TargetBranch)) {
            throw 'TargetBranch is required for remove.'
        }
        if (@(Invoke-Git -WorkingDirectory $worktreePath status --porcelain).Count -gt 0) {
            throw 'Worktree is dirty and will be preserved.'
        }

        $mergedBranches = @(Invoke-Git -WorkingDirectory $repoRoot branch --merged $TargetBranch)
        if (-not ($mergedBranches | ForEach-Object { $_.Trim().TrimStart('*', '+').Trim() } | Where-Object { $_ -eq $branchName })) {
            throw "Branch '$branchName' is not merged into '$TargetBranch'."
        }

        Invoke-Git -WorkingDirectory $repoRoot worktree remove $worktreePath | Out-Null
        Invoke-Git -WorkingDirectory $repoRoot -Arguments @('branch', '-d', $branchName) | Out-Null
        "REMOVED=$worktreePath"
    }
}
