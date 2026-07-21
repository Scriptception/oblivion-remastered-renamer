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

if ($source.Contains('value_param:set')) {
    throw 'Unsafe in-place TMap FString mutation detected; use TMap:Add replacement.'
}

foreach ($requiredToken in @(
    'WBP_LegacyMenu_TextEdit',
    'UserInputTextsMap',
    'map:Add(key, new_name)',
    'map:Find(key)',
    'undo/last-rename.txt',
    'RegisterHook(OK_HOOK',
    'RegisterHook(BACK_HOOK'
)) {
    if (-not $source.Contains($requiredToken)) {
        throw "Required native-dialog safety token was not found: $requiredToken"
    }
}

Write-Host 'Validation passed: F2, native dialog, exact-map rename, undo record, and console safety boundary.'
