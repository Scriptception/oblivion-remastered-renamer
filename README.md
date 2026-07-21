# Oblivion Renamer

[![CI](https://github.com/Scriptception/oblivion-remastered-renamer/actions/workflows/ci.yml/badge.svg)](https://github.com/Scriptception/oblivion-remastered-renamer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Rename player-created spells and player-created enchanted items from inside
**The Elder Scrolls IV: Oblivion Remastered**. Highlight a custom spell or
enchanted item, press **F2**, and enter its new name in the game's native
text-entry screen.

The mod deliberately rejects built-in spells, ordinary equipment, quest
records, and ambiguous matches. It changes only the matching value in the
game's saved custom-name map.

## Downloads

- [Nexus Mods](https://www.nexusmods.com/oblivionremastered/mods/5563) for the
  public mod page and end-user downloads.
- [GitHub Releases](https://github.com/Scriptception/oblivion-remastered-renamer/releases)
  for matching release archives, checksums, and source history.

## Features

- Renames player-created spells and named enchanted items.
- Uses Oblivion's native in-game text-entry screen.
- Persists through normal game saves and reloads.
- Preserves prefixes, leading spaces, and sorting tags exactly as entered.
- Handles Inventory rows that still display the previous name after a rename.
- Writes a recovery record before every change.
- Allows exact-key enchanted items to share names while rejecting unsafe
  ambiguous spell or fallback-item matches.
- Rejects empty names, control characters, and names longer than 80 Unicode
  characters.
- Never invokes the developer console.

## Requirements and support

- A working [UE4SS for OblivionRemastered](https://www.nexusmods.com/oblivionremastered/mods/32)
  installation.
- Tested on the Xbox app / PC Game Pass `WinGDK` build, package version
  `1.0.12.0`.
- Tested with UE4SS `v3.0.1 Beta #0`, Git SHA `437a8ff`.
- The Steam `Win64` build is not yet runtime-tested and is not claimed as
  supported in v1.1.0.

The release was tested alongside FuzzUI - Interface Tweaks 2.0.0, Inventory
Sorting Tags 1.5 Non-Deluxe, Press E To Confirm 1.0, Spell Hotkeys 1.2.5, and
NL Tag Remover 1.3.3.

## Installation

1. Install and verify UE4SS for Oblivion Remastered.
2. Close the game completely.
3. Download the latest `OblivionRenamer-<version>.zip` from
   [Nexus Mods](https://www.nexusmods.com/oblivionremastered/mods/5563?tab=files)
   or [GitHub Releases](https://github.com/Scriptception/oblivion-remastered-renamer/releases).
4. Extract the ZIP into the directory containing the game's shipping
   executable and existing `ue4ss` folder:
   - Xbox app / Game Pass: `OblivionRemastered\Binaries\WinGDK`
   - Steam, untested: `OblivionRemastered\Binaries\Win64`
5. Confirm this file exists:
   `ue4ss\Mods\OblivionRenamer\scripts\main.lua`.

The final layout is:

```text
WinGDK
`-- ue4ss
    `-- Mods
        `-- OblivionRenamer
            |-- enabled.txt
            |-- scripts
            |   `-- main.lua
            `-- undo
```

## Usage

### Rename a custom spell

1. Open **Magic** and highlight a player-created spell with the mouse or
   keyboard. It does not need to be the equipped spell.
2. Press **F2**.
3. Enter the new name and choose **OK**, or choose **Back/Escape** to cancel.
4. Reopen Magic if the list has not refreshed, then make a normal game save.

If Spell Hotkeys is installed, rebind the renamed spell. Spell Hotkeys stores
the displayed spell name in its own save state, and Oblivion Renamer does not
rewrite another mod's private data.

### Rename a custom enchanted item

1. Open **Inventory** and highlight an item created and named at an enchanting
   altar with the mouse or keyboard. You do not need to click it.
2. Press **F2** and confirm the new name.
3. Close the full player menu and reopen Inventory to refresh the displayed
   row, then make a normal game save.

The Inventory row may continue to show the previous name until the player menu
is reopened. A second F2 press is still safe: the mod uses the current saved
value associated with the item's stable key.

Both menus target the currently highlighted row. Clicking or equipping a spell
or item is not required, which avoids unrelated equipment changes.

## Safety and recovery

Before changing a name, the mod writes:

```text
ue4ss\Mods\OblivionRenamer\undo\last-rename.txt
```

The record contains the stable saved-name key, old value, new value, record
kind, and item identifiers when available. Only the most recent rename is
retained. It is a recovery aid, not an automatic undo button.

Renames remain in memory until the player makes a normal game save. Keep a
backup save while evaluating any mod that changes save-backed data.

## Compatibility notes

- Sorting prefixes and tags are ordinary name text and are preserved.
- Player-created enchanted items may share a name with another custom item or
  spell when the highlighted item's stable saved-name key is available. The
  hovered item's dynamic form keeps later renames unambiguous.
- Spell destination names already used by another custom entry remain rejected
  until the Magic row can be bound to its stable saved-name key.
- Oblivion itself can create duplicate custom names. The Magic row exposes its
  displayed name and inventory index, but not its stable saved-name key. If two
  custom creations already share a displayed name, the mod refuses to guess
  which saved entry to change. Reopen Magic and retry if the duplicate was only
  a temporary, unsaved state.
- Built-in content is intentionally outside this mod's scope; use a dedicated
  sorting/tagging mod for ordinary records.
- Game updates or different UE4SS builds may change reflected APIs. Include the
  game build, UE4SS version, and `ue4ss\UE4SS.log` when reporting a problem.

## Achievements

Oblivion Renamer does not execute the developer console or intentionally enable
developer mode. Achievement behavior is ultimately controlled by the game,
platform, and the user's wider UE4SS setup, so the mod does not guarantee
achievement compatibility.

## Updating and uninstalling

Close the game before updating or uninstalling.

- To update, replace `ue4ss\Mods\OblivionRenamer` with the new release folder.
- To uninstall, remove that folder.
- Names already persisted in a game save remain after uninstalling. Rename them
  to the desired final values before removal if necessary.

## Development

Run the validation and packaging scripts from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate.ps1
npx --yes luaparse@0.3.1 .\src\OblivionRenamer\scripts\main.lua > $null
npx --yes @johnnymorganz/stylua-bin@2.5.2 --check .\src\OblivionRenamer\scripts\main.lua
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\package.ps1
```

See [Architecture](docs/ARCHITECTURE.md), [Testing](docs/TESTING.md),
[Roadmap](docs/ROADMAP.md), and [Contributing](CONTRIBUTING.md) for the release
safety model and planned native spell-identity research.

## License and disclaimer

Source code is available under the [MIT License](LICENSE).

This is an unofficial fan-made mod. It is not affiliated with or endorsed by
Bethesda Softworks, Virtuos, Xbox, or Microsoft. No game assets are included.
