[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, 128)]
    [string]$Pattern,

    [ValidateSet('Process', 'User', 'Machine')]
    [string[]]$Scope = @('Process', 'User', 'Machine')
)

$ErrorActionPreference = 'Stop'

try {
    $regex = [regex]::new(
        $Pattern,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase,
        [TimeSpan]::FromMilliseconds(250)
    )
}
catch {
    throw 'Pattern must be a valid, bounded regular expression.'
}

foreach ($currentScope in $Scope) {
    $variables = [Environment]::GetEnvironmentVariables($currentScope)
    foreach ($name in @($variables.Keys | Sort-Object)) {
        if (-not $regex.IsMatch([string]$name)) {
            continue
        }

        $value = [string]$variables[$name]
        [pscustomobject]@{
            Scope = $currentScope
            Name = [string]$name
            IsSet = -not [string]::IsNullOrEmpty($value)
            Length = $value.Length
        }
    }
}
