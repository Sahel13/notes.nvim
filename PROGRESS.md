# Progress

## Completed (prior commits)
- Add wiki-link completion source (blink.cmp) scanning Markdown files in :pwd.
- Add contributor guide and test harness (AGENTS.md, scripts/test.sh, tests/).

## Completed (current changes)
- Completion now appends missing closing brackets for wiki-links; accepts `[[name]]` without manual `]]`.
- Added Plenary test covering completion suffix behavior for missing `]]` and `]` cases.
- `scripts/test.sh` now defaults `PLENARY_PATH` to `$HOME/.local/share/nvim/lazy/plenary.nvim` (still overridable).

## Tests run
- `scripts/test.sh`
