# Oblivion Renamer

An in-game renamer for player-created spells and enchanted items in **The
Elder Scrolls IV: Oblivion Remastered**.

## Project status

Pre-alpha. The current development build opens Oblivion's native in-game text
entry screen when **F2** is pressed on a highlighted player-created spell. Type
the new name and use **Enter/OK** to apply it or **Escape/Back** to cancel.

The build changes only the matching entry in the game's saved custom-name map.
It rejects built-in spells and any ambiguous duplicate-name match, writes an
undo record before changing memory, and asks the player to make a normal game
save after a successful rename.

F2 on a highlighted Inventory entry currently runs a read-only identity probe
for the enchanted-item implementation. It writes diagnostics only and cannot
rename or otherwise alter an item in this build.

## Target design

- Highlight a player-created spell or enchanted item and press F2.
- Enter a new name in an in-game text field.
- Persist the rename through save/load.
- Reject built-in spells, powers, quest abilities, and unsafe records.
- Record enough information to undo the last rename.
- Preserve alphabetical sorting and user-supplied tags.
- Integrate safely with Spell Hotkeys, Inventory Sorting Tags, and MISS.

## Platforms

- Primary target: Microsoft Store / Xbox app / PC Game Pass (`WinGDK`).
- Planned: Steam (`Win64`) after the Game Pass implementation is stable.
- Requires UE4SS for Oblivion Remastered.
- Does not require OBSE64; official OBSE64 does not support Game Pass.

## Achievements

The mod does not open or execute the developer console. It is designed not to
trigger the game's developer-mode achievement block. Until release testing is
complete, achievement compatibility is not guaranteed.

## Safety

Development builds must be tested against a backed-up save. The first mutating
build uses the verified custom-name persistence path, but save/reload testing is
still required before it is release-ready.

## License

MIT. See [LICENSE](LICENSE).
