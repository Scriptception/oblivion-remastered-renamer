$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$main = Join-Path $repoRoot 'src\OblivionRenamer\scripts\main.lua'
$enabled = Join-Path $repoRoot 'src\OblivionRenamer\enabled.txt'

foreach ($required in @($main, $enabled)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing required file: $required"
    }
}

$source = Get-Content -LiteralPath $main -Raw
if ($source -notmatch 'RegisterKeyBind\(Key\.F2') {
    throw 'F2 key binding was not found.'
}

$forbidden = @(
    'ProcessConsoleExec',
    'DeleteGameInSlot',
    'os.execute',
    'io.popen'
)
foreach ($token in $forbidden) {
    if ($source.Contains($token)) {
        throw "Forbidden API detected in probe: $token"
    }
}

Write-Host 'Validation passed: required files, F2 binding, and probe safety boundary.'

