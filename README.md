# Oblivion Renamer

An in-game renamer for player-created spells and enchanted items in **The
Elder Scrolls IV: Oblivion Remastered**.

## Project status

Pre-alpha. The current build is a read-only registry probe. While the Magic menu
is open, highlight a spell and press **F2**. The probe records the selected
spell, its underlying hovered form (when the game exposes one), reflected
function signatures, the game's existing spellmaking widget, and likely Altar
rename/persistence APIs to:

`ue4ss/Mods/OblivionRenamer/diagnostics/latest.txt`

It loads the spellmaking UI asset for reflection, but does not display or invoke
it. It does not invoke hover handlers or modify the selected spell, game files,
or save data.

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

Development builds must be tested against a backed-up save. The mutating
renamer will not be enabled until the persistence path has been verified.

## License

MIT. See [LICENSE](LICENSE).
