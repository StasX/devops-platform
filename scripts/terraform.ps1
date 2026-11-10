$ErrorActionPreference = 'Stop'
$envPath = Join-Path $PSScriptRoot '../.env'
$targetCloud = 'aws'
if ($args.Count -gt 0 -and $args[0] -in @('aws', 'gcp', 'azure', 'vsphere')) {
    $targetCloud = $args[0]
    $args = @($args | Select-Object -Skip 1)
}
$terraformPath = Join-Path $PSScriptRoot "../terraform/$targetCloud"
if (-not (Test-Path -LiteralPath $envPath)) {
    throw 'Missing root .env. Copy .env.example to .env and configure it first.'
}

# Parse literal KEY=VALUE lines without executing file contents.
$entries = @{}
$lineNumber = 0
foreach ($line in [System.IO.File]::ReadAllLines($envPath)) {
    $lineNumber++
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
    if ($trimmed -notmatch '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        throw "Invalid .env assignment on line $lineNumber. Expected KEY=VALUE."
    }
    $name = $Matches[1]
    $value = $Matches[2].Trim()
    if ($value.Length -ge 2) {
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }
    $entries[$name] = $value
}

# Restore the caller's environment after Terraform finishes.
$previous = @{}
try {
    foreach ($name in $entries.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $entries[$name], 'Process')
    }
    & terraform "-chdir=$terraformPath" @args
    $terraformExitCode = $LASTEXITCODE
} finally {
    foreach ($name in $previous.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
exit $terraformExitCode
