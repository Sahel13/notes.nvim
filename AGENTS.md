# Repository Guidelines

## Project Structure & Module Organization
- `lua/notes.lua` contains the plugin’s Lua implementation and is the primary entry point today.
- `plugin/` is reserved for Neovim runtime entrypoints (currently empty).
- `requirements.json` documents expected behaviors and manual acceptance steps.

## Build, Test, and Development Commands
This plugin has no build step.
- Run locally in Neovim: `nvim` (open with `:pwd` set to your notes directory).
- Run tests (requires `plenary.nvim`): `PLENARY_PATH=/path/to/plenary.nvim scripts/test.sh`.
- If you add backlinks, ensure ripgrep is available: `rg --version`.

## Coding Style & Naming Conventions
- Follow existing Lua style in `lua/notes.lua` and keep formatting minimal and readable.
- Prefer 2-space indentation for new Lua blocks to stay compact.
- Use descriptive, lowercase-with-underscores for Lua locals and functions (e.g., `find_backlinks`).
- Add brief doc comments for new functions that describe what they do (not how).

## Testing Guidelines
- Automated tests live in `tests/` and run via Plenary/Busted in headless Neovim.
- Use the manual scenarios in `requirements.json` as the acceptance checklist.
- When adding a feature, update or append steps in `requirements.json` to reflect new behavior.

## Commit & Pull Request Guidelines
- This repository has no commit history yet, so no established convention exists.
- Use concise, informative commit titles (short, imperative).
- Include a descriptive commit body explaining what features were implemented and how.
- For PRs, include a brief summary, any updated `requirements.json` steps, and a note on how you manually verified changes.

## Agent-Specific Notes
- Keep behavior constrained to the current working directory (`:pwd`) as outlined in `requirements.json`.
- Avoid adding dependencies unless required for new functionality.
