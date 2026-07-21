# Oblivion Renamer development instructions

## Product scope

- Rename only player-created spells and player-created named/enchanted items.
- Do not rename built-in records; leave ordinary sorting and tagging to MISS or
  dedicated tagging mods.
- Never reinstall or depend on More Quick Keys. Its cloud-backed data caused a
  confirmed startup `Fatal Error` on this Xbox/Game Pass installation.

## Safety rules

- Require the game process to be closed before installing a development build.
- Keep discovery and probe builds read-only until their reflected types and
  target identity are verified.
- Never pass a Lua string to an Unreal `TextProperty`. Construct `FText(value)`
  first. In particular, `UserInputTextsMap` is `TMap<FString, FText>`.
- Never mutate a TMap key during iteration.
- Write the undo record before a persistent mutation and verify the result
  before asking the tester to save.
- Do not use developer-console commands or destructive save operations.

## Development workflow

1. Run `tools/validate.ps1`.
2. Install only with `tools/install-dev.ps1` while the game is closed.
3. Test one bounded behavior at a time without saving unless verification has
   succeeded.
4. Read `ue4ss/UE4SS.log` and `undo/last-rename.txt` after every failed test.
5. Package with `tools/package.ps1` only after validation passes.

The Xbox/Game Pass target is the `WinGDK` build. The current runtime is UE4SS
3.0.1 Beta commit `437a8ff`.
