# Changelog

## 0.1.2-dev

- Replaced the crashing UE4SS 3.0.1a in-place `FString` map-value write with
  `TMap:Add`, which replaces the existing key/value pair through the supported
  map API.
- Added a post-write lookup and rollback attempt if the replacement cannot be
  verified.
- Added validation that rejects the known-crashing `value_param:set` pattern.

## 0.1.1-dev

- Fixed discovery of the cooked native text-edit widget class.
- Confirmed that the in-game dialog, keyboard entry, and OK action load.
- Known failure: confirming a rename crashed while writing through the
  temporary value parameter returned by `TMap:ForEach`; the undo record remained
  at `status=pending` and the game was not saved.

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
