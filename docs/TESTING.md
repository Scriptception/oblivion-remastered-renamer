# Testing

## Automated checks

Every push and pull request must pass:

- PowerShell source-contract validation.
- Lua 5.3 rename-dialog regression scenarios (`lua5.3 tests/rename_dialog.lua`).
- Lua 5.3 syntax parsing with `luaparse`.
- Release archive construction and layout verification.
- SHA-256 checksum generation.

## Manual release checklist

Use a backed-up test save and the exact release-candidate archive.

### Startup and UI

- The game reaches the main menu and loads a save without a fatal error.
- F2 outside Magic and Inventory shows guidance and changes nothing.
- Escape cancels the rename screen without changing the name.
- Enter confirms; normal game text-edit dialogs still behave as before.
- The independent widget is visible, centred and readable at 720p, 1080p and
  the player’s normal display/UI scale. Typing and validation keep focus.
- Rapid F2/Enter/Escape presses do not open duplicate screens or affect a later
  screen. Cancelling immediately after F2 must not restore focus to a closed screen.
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

- Immediately after enchanting, rename the new item without a chest transfer:
  test 30, 31 and 80 characters, then cancel a second attempt. There must be no
  crash, original 30-character warning or extra enchantment operation.
- Verify item quantity, enchantment, charges and soul gems are unchanged.
- Repeat on a previously enchanted item, after a chest transfer and after reload.
- Verify ordinary enchanting still enforces its own 30-character limit.

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

## v1.1.1-rc.1 candidate status

Automated tests use UE4SS contract doubles. They exercise isolated widget creation,
game-thread object access, a fresh item’s exact key, 30/31/80-character names,
Unicode limits, stale Inventory candidates, repeated renames, cancellation,
invalidated objects, setup failures and recovery-record ordering. They cannot
reproduce native memory faults, confirm reflected APIs on a particular game build,
or establish rendering, actual input routing or save/reload behaviour.

All manual checks above are pending for this candidate. Obtain the F2 reporter’s
game/UE4SS versions and relevant log/crash stack; the first report is too broad to
confirm its root cause. Test Steam Win64 and the previously tested WinGDK target
separately. Do not tag or publish the candidate until its exact archive passes.

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
