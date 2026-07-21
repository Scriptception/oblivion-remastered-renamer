# Roadmap

This roadmap records intended work, not a compatibility promise. A feature is
released only after the exact packaged build passes the manual test checklist.

## v1.1.0: Duplicate enchanted-item names

Status: released in v1.1.0.

- Allow player-created enchanted items to share a displayed name when the
  highlighted item's dynamic form exposes its exact `UI_UserInputText_*` key.
- Continue rejecting ambiguous fallback-item matches.
- Continue rejecting duplicate custom spells and duplicate spell destination
  names rather than guessing their saved identity.

## Future: Duplicate custom spells

Status: planned native research; not part of v1.1.0.

The reflected Magic row exposes its displayed name, inventory index, school,
and type, but not the stable saved-name key or underlying spell Form ID. A Lua
implementation therefore cannot safely distinguish two player-created spells
that share a name.

The next investigation should use a native UE4SS C++ mod or a narrowly scoped
ASI bridge to bind the highlighted row to a stable spell identity. Research
must begin with read-only inspection and remain isolated from the release Lua
mod until the identity mapping is proven.

### Safety requirements

- Never choose a spell by saved-map order, inventory position, school, type, or
  a temporary rename.
- Never invoke a Magic-menu refresh with guessed Blueprint parameters.
- Preserve the existing pending recovery record, typed `FText` write, exact
  readback, and rollback transaction.
- Keep built-in spells, powers, abilities, and quest content out of scope.
- Preserve Xbox app / PC Game Pass `WinGDK` support; do not claim Steam support
  until that build is tested separately.
- Leave the current safe ambiguity rejection in place whenever stable identity
  cannot be proven.

### Acceptance tests

- Create two custom spells with the same name but different effects, then
  rename either one independently from the highlighted Magic row.
- Repeat with mouse and keyboard navigation and with a different spell
  equipped.
- Confirm both identities remain correct after closing the menu, saving,
  exiting, relaunching, and loading the save.
- Confirm a same-named enchanted item does not affect spell targeting.
- Confirm unique spell renaming, cancellation, recovery records, and Spell
  Hotkeys guidance still work.
- Complete the test pass without a freeze, fatal error, or relevant UE4SS log
  error.
