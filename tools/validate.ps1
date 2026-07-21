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
    throw 'Unsafe in-place TMap FText mutation detected; use typed TMap:Add replacement.'
}

foreach ($unsafeTextWrite in @(
    'map:Add(key, new_name)',
    'map:Add(key, old_name)'
)) {
    if ($source.Contains($unsafeTextWrite)) {
        throw "Unsafe plain-string write to an FText map value detected: $unsafeTextWrite"
    }
}

foreach ($requiredToken in @(
    'WBP_LegacyMenu_TextEdit',
    'UserInputTextsMap',
    'local replacement_text = FText(new_name)',
    'map:Add(key, replacement_text)',
    'local original_text = FText(old_name)',
    'map:Add(key, original_text)',
    'map:Find(key)',
    'undo/last-rename.txt',
    'RegisterHook(OK_HOOK',
    'RegisterHook(BACK_HOOK'
)) {
    if (-not $source.Contains($requiredToken)) {
        throw "Required native-dialog safety token was not found: $requiredToken"
    }
}

foreach ($requiredProbeToken in @(
    'INVENTORY_MENU_PAGE = 1',
    'GetInventoryHoveredObjectForm',
    'GetCurrentPageItemsInventory',
    'bIsEnchantedObject',
    'EnchantSaveData',
    'SourceFormID',
    'diagnostics/item-probe.txt',
    'read_only=true'
)) {
    if (-not $source.Contains($requiredProbeToken)) {
        throw "Required read-only item probe token was not found: $requiredProbeToken"
    }
}

$mutationFunctionStart = $source.IndexOf('local function mutate_saved_name')
$mutationFunctionEnd = $source.IndexOf('local function write_undo_record')
if ($mutationFunctionStart -lt 0 -or $mutationFunctionEnd -le $mutationFunctionStart) {
    throw 'Could not identify the bounded saved-name mutation function.'
}
$outsideMutationFunction = $source.Remove(
    $mutationFunctionStart,
    $mutationFunctionEnd - $mutationFunctionStart
)
if ($outsideMutationFunction.Contains('map:Add(')) {
    throw 'Saved-name map mutation was found outside the bounded rename function.'
}

Write-Host 'Validation passed: spell rename, typed FText map replacement, undo record, read-only item probe, and console safety boundary.'
