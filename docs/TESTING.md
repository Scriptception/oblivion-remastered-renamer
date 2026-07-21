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
- Pre-existing duplicate custom names are rejected rather than resolving one by
  map order.
- Spell Hotkeys users receive a rebind notice.

### Custom enchanted item

- A player-created named enchanted item can be renamed.
- Mouse and keyboard navigation both target the currently highlighted Inventory
  row without equipping or unequipping it.
- A second rename works before the stale Inventory row refreshes.
- The list refreshes after closing and reopening the player menu.
- Repeated player-menu close/reopen cycles continue to target the highlighted
  row on the first F2 attempt, without selecting a stale Inventory widget.
- The final name persists after save, exit, relaunch, and reload.
- A built-in or unenchanted item is rejected.
- Two key-resolved custom enchanted items can be given the same displayed name,
  and hovering either one still renames only that item.
- A key-resolved custom enchanted item can share a name with a custom spell.
- A fallback item whose form does not expose a saved-name key still rejects a
  duplicate destination name.

### Validation and recovery

- Blank, control-character, and over-80-character names are rejected.
- A successful rename creates `undo/last-rename.txt` with `status=applied`.
- `UE4SS.log` contains no Oblivion Renamer error after the test pass.

Record the game distribution, package version, UE4SS version and Git SHA, other
installed UI/hotkey mods, and the archive checksum with the release evidence.

## v1.1.0 release evidence

- Tested on 2026-07-21 with the Xbox app / PC Game Pass `WinGDK` package
  version `1.0.12.0` and UE4SS `v3.0.1 Beta #0`, Git SHA `437a8ff`.
- Tested archive: `OblivionRenamer-1.1.0.zip`.
- SHA-256: `05022D0585058A9AE1950CD431BF618F08CF7469186EC95172F5B4F4A8003765`.
- Co-installed mods: FuzzUI - Interface Tweaks 2.0.0, Inventory Sorting Tags
  1.5 Non-Deluxe, Press E To Confirm 1.0, Spell Hotkeys 1.2.5, and NL Tag
  Remover 1.3.3.
- Two enchanted items were assigned the same name, targeted independently
  after repeated player-menu reopen cycles, saved, reloaded after a full game
  restart, and renamed independently again.
- The test also covered sharing that name with existing custom spell entries.
- The final recovery record was `status=applied`, and the fresh UE4SS log
  contained no Oblivion Renamer error.
- Steam `Win64` remains untested and is not claimed as supported.
