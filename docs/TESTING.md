# Testing

## Automated checks

Every push and pull request must pass:

- PowerShell source-contract validation.
- Lua 5.3 syntax parsing with `luaparse`.
- Release archive construction and layout verification.
- SHA-256 checksum generation.

## Manual release checklist

Use a backed-up test save and the exact release-candidate archive.

### Startup and UI

- The game reaches the main menu and loads a save without a fatal error.
- F2 outside Magic and Inventory shows guidance and changes nothing.
- Escape/Back cancels the native rename screen without changing the name.
- Confirming an unchanged name changes nothing.

### Custom spell

- A player-created spell can be renamed.
- Mouse and keyboard navigation both target the currently highlighted spell,
  even when a different spell is equipped.
- The Magic list refreshes after reopening it.
- The new name persists after save, exit, relaunch, and reload.
- A built-in spell is rejected.
- A duplicate target name is rejected.
- Spell Hotkeys users receive a rebind notice.

### Custom enchanted item

- A player-created named enchanted item can be renamed.
- Mouse and keyboard navigation both target the currently highlighted Inventory
  row without equipping or unequipping it.
- A second rename works before the stale Inventory row refreshes.
- The list refreshes after closing and reopening the player menu.
- The final name persists after save, exit, relaunch, and reload.
- A built-in or unenchanted item is rejected.

### Validation and recovery

- Blank, control-character, and over-80-character names are rejected.
- A successful rename creates `undo/last-rename.txt` with `status=applied`.
- `UE4SS.log` contains no Oblivion Renamer error after the test pass.

Record the game distribution, package version, UE4SS version and Git SHA, other
installed UI/hotkey mods, and the archive checksum with the release evidence.
