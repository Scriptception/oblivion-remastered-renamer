$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$main = Join-Path $repoRoot 'src\OblivionRenamer\scripts\main.lua'
$enabled = Join-Path $repoRoot 'src\OblivionRenamer\enabled.txt'
$versionFile = Join-Path $repoRoot 'VERSION'

foreach ($required in @($main, $enabled, $versionFile)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing required file: $required"
    }
}

$source = Get-Content -LiteralPath $main -Raw
$version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw "VERSION is not valid SemVer: $version"
}
$sourceVersionMatch = [regex]::Match($source, 'local MOD_VERSION = "([^"]+)"')
if (-not $sourceVersionMatch.Success -or $sourceVersionMatch.Groups[1].Value -ne $version) {
    throw "VERSION and main.lua MOD_VERSION do not match: $version"
}

if ($source -notmatch 'RegisterKeyBind\(Key\.F2') {
    throw 'F2 key binding was not found.'
}
if ($source.Contains('GetCurrentSpellEquiped')) {
    throw 'Equipped-spell targeting detected; Magic renames must follow the highlighted row.'
}

$forbidden = @(
    'ProcessConsoleExec',
    'DeleteGameInSlot',
    'os.execute',
    'io.popen'
)
foreach ($token in $forbidden) {
    if ($source.Contains($token)) {
        throw "Forbidden API detected in mod source: $token"
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
    'local replacement_text = safe("construct replacement FText"',
    'return FText(new_name)',
    'map:Add(key, replacement_text)',
    'local original_text = safe("construct rollback FText"',
    'return FText(old_name)',
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

foreach ($requiredItemToken in @(
    'INVENTORY_MENU_PAGE = 1',
    'WBP_OriginalMenu_Inventory_C',
    'CurrentHoveredItem',
    'hovered_item:GetProperties()',
    'bIsEnchantedObject',
    'EnchantSaveData',
    'SourceFormID',
    'open_item_rename_dialog',
    'find_saved_name_target_by_key',
    'Inventory row name is stale; using current saved value',
    'keyed_target.current_value',
    'Resolved reloaded custom item through its unique saved-name value',
    '^UI_UserInputText_',
    'string.lower(form_id)',
    'entity_kind = "custom-enchanted-item"'
)) {
    if (-not $source.Contains($requiredItemToken)) {
        throw "Required custom-item safety token was not found: $requiredItemToken"
    }
}

foreach ($requiredSpellToken in @(
    'WBP_ModernMenu_MagicMenu_C',
    'read Magic menu CurrentHoveredItem',
    'read highlighted spell properties',
    'HasFocusedDescendants',
    'get_highlighted_magic_spell'
)) {
    if (-not $source.Contains($requiredSpellToken)) {
        throw "Required highlighted-spell targeting token was not found: $requiredSpellToken"
    }
}

foreach ($requiredHardeningToken in @(
    'count_saved_name_conflicts',
    'Names cannot contain control characters.',
    'has_active_dialog',
    'Could not finalize undo record',
    'SPELL_HOTKEYS_STATE_PATH',
    'rebind it in Spell Hotkeys'
)) {
    if (-not $source.Contains($requiredHardeningToken)) {
        throw "Required release-hardening token was not found: $requiredHardeningToken"
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

$parseErrors = @()
foreach ($script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $script.FullName,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    $parseErrors += $errors
}
if ($parseErrors.Count -gt 0) {
    throw "PowerShell syntax validation failed: $($parseErrors[0].Message)"
}

Write-Host 'Validation passed: custom spell/item guards, typed FText replacement, undo record, and console safety boundary.'
