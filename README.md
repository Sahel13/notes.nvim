# notes.nvim

Minimal wiki-link support for Markdown notes in the current working directory.

## Requirements

- `rg` (ripgrep) is required for backlinks search; other features work without it.

## Configuration

```lua
require("notes").setup({
  mappings = {
    follow = "<CR>",
    back = "<BS>",
    backlinks = "<leader>nb",
  },
})
```

Set a mapping to `false` to disable it.
