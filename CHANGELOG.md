# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 1.1.1-rc.1 - 2026-09-30

### Fixed

- Replace the legacy enchanting text-entry Blueprint with a rename-only native
  Unreal widget, avoiding its original OK/Back handlers and 30-character warning.
  Enter confirms and Escape cancels; clickable OK/Back buttons are removed.
- Queue delayed focus restoration and keyboard object checks onto the game thread.
- Read Inventory row/form properties only after selecting the active widget.

### Development

- Add Lua regression scenarios and CI checks for dialog isolation, threading,
  fresh-item key resolution, length validation, cancellation and recovery records.
- Include hidden staging files when packaging on Linux as well as Windows.
- This candidate is not runtime-tested. Crash resolution and platform compatibility
  remain subject to the manual release checklist.

## [1.1.0] - 2026-07-21

### Added

- Allow player-created enchanted items with exact saved-key identity to share
  names with other custom items or spells.
- Document native spell-identity research as future work rather than extending
  v1.1.0 with an unsafe Lua heuristic.

### Fixed

- Prefer the focused Inventory widget after menu reopen, avoiding stale widget
  instances that can expose the wrong underlying form.

### Safety

- Keep duplicate destination names blocked for spells and fallback item
  resolution until the highlighted row can be bound to an exact saved key.

## [1.0.1] - 2026-07-21

### Fixed

- Made release archives byte-for-byte reproducible across local PowerShell and
  GitHub-hosted Windows runners by fixing packaged text line endings and using
  implementation-independent stored ZIP entries.

## [1.0.0] - 2026-07-21

### Added

- Native in-game F2 rename flow for player-created spells.
- Guarded F2 rename flow for player-created named enchanted items.
- Save/load persistence through the game's `UserInputTextsMap`.
- Pre-write recovery record at `undo/last-rename.txt`.
- Duplicate-name, blank-name, control-character, and length validation.
- Detection and recovery for stale Inventory rows after an item rename.
- Contextual refresh guidance and a Spell Hotkeys rebind notice.
- Mouse and keyboard targeting of the highlighted Magic row rather than the
  equipped spell.
- Reproducible release packaging, SHA-256 checksums, and CI validation.

### Safety

- Reject built-in and ambiguous records.
- Require dynamic form, enchant-save, source-form, and saved-name identity for
  enchanted items.
- Construct typed `FText` values before replacing the Unreal map entry.
- Verify every replacement and attempt rollback if verification fails.
- Never invoke the developer console or issue save commands.

[Unreleased]: https://github.com/Scriptception/oblivion-remastered-renamer/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/Scriptception/oblivion-remastered-renamer/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/Scriptception/oblivion-remastered-renamer/releases/tag/v1.0.1
[1.0.0]: https://github.com/Scriptception/oblivion-remastered-renamer/releases/tag/v1.0.0
