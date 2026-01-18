# Repository Guidelines

## Project Structure & Module Organization
- `lua/notes.lua` contains the plugin’s Lua implementation and is the primary entry point today.
- `plugin/` is reserved for Neovim runtime entrypoints.
- `doc/` contains the documentation for the plugin.

## Build, Test, and Development Commands
This plugin has no build step.
- Run locally in Neovim: `nvim` (open with `:pwd` set to your notes directory).
- Run tests (requires `plenary.nvim`): `scripts/test.sh`.
- If you add backlinks, ensure ripgrep is available: `rg --version`.

## Coding Style & Naming Conventions
- Follow existing Lua style in `lua/notes.lua` and keep formatting minimal and readable.
- Use descriptive, lowercase-with-underscores for Lua locals and functions (e.g., `find_backlinks`).
- Add brief doc comments for new functions that describe what they do (not how).

## Testing Guidelines
- Automated tests live in `tests/` and run via Plenary/Busted in headless Neovim.
- Always add tests for any new functionality that is implemented.
- Always run tests and ensure they pass after you're done modifying code.
- Format Lua files with `stylua` before committing changes.

## Commit & Pull Request Guidelines
- Use concise, informative commit titles (short, imperative).
- Include a descriptive commit body explaining what features were implemented and how.
- For PRs, include a brief summary and a note on how you manually verified changes.

## Agent-Specific Notes
- Keep behavior constrained to the current working directory (`:pwd`).
- Avoid adding dependencies unless required for new functionality.
- If any functionality has changed, update `doc/notes.txt` to document it properly.
