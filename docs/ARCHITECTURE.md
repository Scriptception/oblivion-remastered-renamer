# Architecture

## Safety boundary

The probe and final mod run on UE4SS. No developer-console commands are used.
The probe is read-only. A later mutating build must create an undo record and
must verify the replacement record before removing or changing an old one.

## Rename flow

1. Require the relevant inventory menu to be open.
2. Resolve the currently highlighted entry from its view model.
3. Reject records that are not player-created or are otherwise unsafe.
4. Open an Unreal text-entry widget and validate the requested name.
5. Persist the new name through the game's legacy/Unreal bridge.
6. Refresh the menu and verify that the new name resolves to the same record.
7. Migrate matching Spell Hotkeys metadata or tell the user to rebind it.
8. Write an undo record containing the stable identity and original name.

## Sorting and tag compatibility

The user-entered string remains the real inventory name, so alphabetical
sorting naturally follows it. Prefixes such as `[Atk]`, `[Heal]`, or invisible
sorting characters are preserved verbatim.

MISS does not rewrite player-created spell or enchanted-item names, so it can
coexist with this mod. Static sorting mods may still change built-in records;
the renamer deliberately does not own those records.

## Current probe

The registry probe logs the selected spell row, `InventoryHoveredObjectForm`,
stable function signatures, and a bounded list of likely Altar persistence
APIs. The Magic menu does not populate its hovered-form bridge for spells, so
the probe also loads the existing spellmaking widget for reflection and scans
its classes/functions without displaying or invoking it. It deliberately does
not invoke `RegisterSendItemHoverHandler` or any creation/save action. This
establishes which later call can write through to the legacy record and save
rather than changing only a transient menu value.
