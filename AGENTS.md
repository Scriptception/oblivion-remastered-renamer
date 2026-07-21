# Repository instructions

## Product scope

- Rename only player-created spells and player-created named enchanted items.
- Never mutate built-in records, quest content, powers, or ordinary equipment.
- Treat external sorting, tagging, and hotkey save data as owned by those mods.

## Runtime safety

- Require the game process to be closed before installing a build.
- Never pass a Lua string to an Unreal `TextProperty`; construct `FText` first.
- Never mutate a `TMap` key during iteration.
- Write a pending recovery record before persistent mutation.
- Verify the replacement by stable key and attempt rollback on failure.
- Do not add developer-console commands or destructive save operations.

## Release workflow

1. Keep `VERSION` and `MOD_VERSION` identical.
2. Run `tools/validate.ps1` and Lua syntax parsing.
3. Build and verify the release archive with `tools/package.ps1`.
4. Install only while the game is closed.
5. Complete `docs/TESTING.md` against a backed-up save.
6. Tag only a commit whose exact archive passed the runtime test.

The supported v1 target is the Xbox app / PC Game Pass `WinGDK` build with
UE4SS 3.0.1 Beta commit `437a8ff`. Do not claim untested platforms.
