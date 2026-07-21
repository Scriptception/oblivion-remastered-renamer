# Architecture

## Safety boundary

The mod runs on UE4SS. No developer-console commands are used. Before changing
a saved name, the development build requires one exact custom-name match and
writes an undo record. It changes the value in place and does not recreate or
remove the spell record.

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

## Current development build

The F2 handler resolves the selected visible spell name to exactly one entry in
`UserInputTextSaveData.UserInputTextsMap`. It loads the game's own
`WBP_LegacyMenu_TextEdit`, focuses its editable field, and connects the native
OK and Back actions to confirm/cancel. Confirmation updates only that map value,
refreshes the selected spell row when possible, and records the old value in
`undo/last-rename.txt`.
