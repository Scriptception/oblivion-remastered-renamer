# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/Scriptception/oblivion-remastered-renamer/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Scriptception/oblivion-remastered-renamer/releases/tag/v1.0.0
