# Architecture

## Runtime

Oblivion Renamer is a single UE4SS Lua mod. F2 dispatches according to the
visible player-menu page:

- Magic resolves `CurrentHoveredItem` from the active
  `WBP_ModernMenu_MagicMenu_C` widget.
- Inventory resolves `CurrentHoveredItem` from the active
  `WBP_OriginalMenu_Inventory_C` widget and reads its item properties.

The native `WBP_LegacyMenu_TextEdit` widget supplies the input screen. Hooks on
its OK and Back actions commit or cancel the active rename.

## Persistence

Player-created names are stored in `UserInputTextSaveData.UserInputTextsMap`, a
`TMap<FString, FText>`. The map key is never changed. The value is replaced with
`TMap:Add(key, FText(new_name))`, then read back and compared before success is
reported.

Passing a plain Lua string into this map's `FText` value slot is unsafe on the
tested UE4SS build. Validation therefore requires explicit `FText` construction
and rejects direct string writes.

## Identity and scope

### Spells

A spell is eligible only when it is the currently highlighted Magic row and its
visible name maps to exactly one saved custom-name entry. Built-in spells,
powers, abilities, and ambiguous duplicate names are rejected. The equipped
spell is not used as an identity fallback.

### Enchanted items

An item must satisfy every guard below:

1. It is the current entry in the active Inventory widget.
2. `CurrentFormID` and `ObjectHoveredFormID` agree when both are available.
3. `bIsEnchantedObject` is true.
4. `EnchantSaveData` is valid and has a nonzero `SourceFormID`.
5. Its form ID begins with `ff`, identifying a save-created dynamic form.
6. Its `UI_UserInputText_*` key maps to one saved name entry, or its displayed
   name maps to exactly one entry when the key string has already been resolved.

The stable key is authoritative after a rename because the visible Inventory
row can remain stale until the full player menu is reopened.

## Transaction boundary

The commit order is:

1. Validate the requested name and check for conflicts.
2. Write `undo/last-rename.txt` with `status=pending`.
3. Revalidate that the original key/value pair still exists exactly once.
4. Replace the value with a typed `FText`.
5. Read the key back and compare it with the requested value.
6. Attempt rollback if verification fails.
7. Rewrite the recovery record with `status=applied`.

No save command is issued. The player decides whether and when to create a
normal game save.

## Compatibility boundary

The mod owns only the game's saved custom-name value. It does not modify built-in
records, sorting-mod data, hotkey-mod data, executable code, or developer-console
state. External mods that store names as identifiers may require rebinding after
a rename.
