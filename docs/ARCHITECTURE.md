# Architecture

## Runtime

Oblivion Renamer is a single UE4SS Lua mod. F2 dispatches according to the
visible player-menu page:

- Magic resolves `CurrentHoveredItem` from the active
  `WBP_ModernMenu_MagicMenu_C` widget.
- Inventory resolves `CurrentHoveredItem` from the active
  `WBP_OriginalMenu_Inventory_C` widget and reads its item properties.

UE4SS can retain more than one valid Inventory widget across player-menu
reopens. The resolver prefers the sole widget with focused descendants, then a
sole viewport candidate. If several stale candidates remain and none owns
focus, it rejects the request rather than inspecting an arbitrary widget.

The rename screen is a native `/Script/Altar.VAltarWidget` host containing a
mod-created UMG widget tree with a prompt, `EditableTextBox` and keyboard
instructions. Enter commits and Escape cancels. There are no clickable OK/Back
buttons or Blueprint text-edit hooks.

The game’s `WBP_LegacyMenu_TextEdit` is deliberately not loaded or instantiated.
Its original handlers run before UE4SS Blueprint post-hooks, so using that screen
also runs legacy text-edit behaviour, including the 30-character enchanting
warning. Re-entry into that bridge is a suspected cause of the freshly enchanted
item crash; no crash dump or in-game reproduction has confirmed it yet.

F2, Enter, Escape and delayed focus restoration perform all Unreal object access
inside `ExecuteInGameThread`. On the supported UE4SS build `ExecuteWithDelay`
runs asynchronously. Delayed and queued keyboard callbacks also check the exact
dialog state so they cannot act on a cancelled or replacement dialog.

Inventory row and form properties are read only after selecting the active widget;
stale non-selected widgets are never queried for their row/form data.

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

The reflected Magic row provides display properties and an inventory index, but
not the stable `UI_UserInputText_*` key. Existing duplicate custom names are
therefore rejected: choosing a key by map order or inventory position would
risk changing the wrong creation.

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

When the dynamic form exposes that stable key directly, the item may share a
displayed name with another custom creation. Name uniqueness is not an identity
requirement for that path. The visible-name fallback still requires a unique
match and keeps the destination-name collision guard.

## Transaction boundary

The commit order is:

1. Validate the requested name. Check for conflicts unless an enchanted item is
   already bound directly to its stable saved-name key.
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

## API evidence

- [UE4SS RegisterHook](https://docs.ue4ss.com/release/lua-api/global-functions/registerhook.html)
  documents Blueprint callbacks as post-hooks, without suppression of the original.
- [UE4SS ExecuteWithDelay](https://docs.ue4ss.com/release/lua-api/global-functions/executewithdelay.html)
  documents asynchronous execution.
- [Altar SDK host declaration](https://github.com/Kein/Altar/blob/main/Source/Altar/Public/VAltarWidget.h)
  exposes the concrete native host; this declaration is reference evidence, not
  runtime validation of the new widget.
