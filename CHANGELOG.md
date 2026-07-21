# Changelog

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
