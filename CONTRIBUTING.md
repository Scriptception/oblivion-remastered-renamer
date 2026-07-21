# Contributing

Thanks for helping improve Oblivion Renamer.

## Before opening a change

- Keep the product scope limited to player-created spells and player-created
  named enchanted items.
- Do not add developer-console commands or broad built-in record mutation.
- Open an issue before changing save-data identity or persistence behavior.

## Development workflow

1. Create a focused branch.
2. Update `VERSION` and `CHANGELOG.md` when behavior or packaging changes.
3. Run the validation, syntax, and packaging commands from the README.
4. Test against a backed-up save with the game closed during installation.
5. Include the exact game distribution and UE4SS build in the pull request.

Never pass a Lua string directly into an Unreal `TextProperty`. The custom-name
map is `TMap<FString, FText>` and requires an `FText` value.

## Bug reports

Use the bug-report template and attach the relevant section of `UE4SS.log`.
Remove usernames, local paths, character names, or other personal information
before posting logs publicly.
