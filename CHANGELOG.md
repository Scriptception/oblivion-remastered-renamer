# Changelog

## 0.3.3-stale-row-dev

- Treat a unique stable custom-name key as authoritative when the Inventory row
  still displays the pre-rename value.
- Prefill a repeated rename with the map's current saved value instead of
  falsely reporting an ambiguity.
- Clarify that Inventory refresh requires closing and reopening the full player
  menu before saving.

## 0.3.2-reload-identity-dev

- Account for reloaded custom items whose `FullName` resolves to their display
  text instead of retaining the original `UI_UserInputText_*` key string.
- Preserve the dynamic-form and enchant-save checks, then allow a fallback only
  when the visible item name resolves to exactly one entry in the saved custom
  name map.
- Capture a fresh read-only item identity report on every Inventory F2 attempt
  while this reload path is being verified.

## 0.3.1-item-rename-dev

- Clarified successful rename notifications for both supported contexts: reopen
  Magic or Inventory to refresh the list, then save the game to persist the
  change.

## 0.3.0-item-rename-dev

- Enabled F2 renaming for a highlighted player-created enchanted item.
- Require the active Inventory widget entry, matching hovered form pointers, an
  `ff` dynamic form ID, valid enchant-save data, a nonzero source form ID, and
  exactly one matching `UI_UserInputText_*` saved-name key before opening the
  dialog.
- Reuse the spell renamer's typed `FText` map replacement, pre-write undo
  record, post-write verification, and native in-game text-entry screen.
- Removed the unsupported copied-array `ForEach` diagnostic call that emitted a
  harmless caught warning during the successful item probe.

## 0.2.1-item-probe-dev

- Replaced the unused global hovered-form bridge with the active Inventory
  widget's `CurrentHoveredItem` and its exact `GetProperties()` row.
- Added guarded fallbacks through the widget's `CurrentFormID` and
  `ObjectHoveredFormID` fields.
- Kept all enchanted-item paths read-only while the new selection identity is
  verified in the target runtime.

## 0.2.0-item-probe-dev

- Removed the optional `SetCurrentSpellEquiped` refresh call. The saved-name
  map already refreshes the visible row, while the extra reflected call could
  emit a caught object-property error after an otherwise successful rename.
- Added F2 context dispatch between Magic and Inventory.
- Added a strictly read-only enchanted-item discovery report that correlates
  the highlighted inventory row, underlying form, enchantment save data, and
  saved custom-name map without changing game or save data.
- Generalized dialog and undo metadata in preparation for item support.

## 0.1.3-dev

- Corrected the saved-name map value type from a plain Lua string to a real
  `FText` object before calling `TMap:Add`.
- Confirmed from the game SDK that `UserInputTextsMap` is
  `TMap<FString, FText>`, and from the exact installed UE4SS source revision
  (`437a8ff`) that its `TextProperty` setter requires `FText` userdata.
- Added validation that rejects plain-string writes to this map, preventing the
  native type-confusion crash from being reintroduced.
- Marked both 0.1.1 and 0.1.2 confirmation crashes as consequences of the same
  incorrect `FText` argument type.

## 0.1.2-dev

- Replaced the crashing UE4SS 3.0.1a in-place map-value write with
  `TMap:Add`, which replaces the existing key/value pair through the supported
  map API.
- Added a post-write lookup and rollback attempt if the replacement cannot be
  verified.
- Added validation that rejects the known-crashing `value_param:set` pattern.
- Known failure: this build still passed a plain Lua string where the map
  required `FText`, so confirming a rename crashed inside UE4SS's native
  `TextProperty` pusher.

## 0.1.1-dev

- Fixed discovery of the cooked native text-edit widget class.
- Confirmed that the in-game dialog, keyboard entry, and OK action load.
- Known failure: confirming a rename crashed while writing a plain Lua string
  into the `FText` value returned by `TMap:ForEach`; the undo record remained at
  `status=pending` and the game was not saved.

## 0.0.4-localization-probe

- Added focused enumeration of `UserInputTextSaveData.UserInputTextsMap`.
- Added correlation of a selected visible spell name to its saved localization
  key.
- Added discovery and inspection of candidate legacy spell-record instances,
  including `FullName` and form identifiers.
- Removed the slow full function-signature scan from the active F2 path.

## 0.0.3-registry-probe

- Replaced the unavailable `FindAllOf("Class")` route with a bounded
  `ForEachUObject` registry scan.
- Added read-only loading and inspection of the existing spellmaking UI asset.
- Added stable `StaticFindObject` resolution for reflected function signatures.
- Improved null-object reporting without noisy `ToString` calls.

## 0.0.2-bridge-probe

- Added read-only capture of `InventoryHoveredObjectForm` and its underlying
  class, properties, values, and function signatures.
- Added reflected signatures for the Magic-menu/UI bridge functions.
- Added a bounded scan of loaded Altar classes for likely rename, record, save,
  and custom-spell APIs.
- Expanded the selected spell row capture to every known field.

## 0.0.1-probe

- Added the F2 read-only selected-spell reflection probe.
- Added WinGDK-safe development installation and packaging scripts.
- Added explicit console-free and non-mutating safety constraints.
