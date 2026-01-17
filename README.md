# notes.nvim

A small note-taking plugin for Neovim inspired by the Zettelkasten style,
emulating a few core [vimwiki](https://github.com/vimwiki/vimwiki) features.

## Features

- Wiki-link completion for `[[...]]` via
[`blink.cmp`](https://github.com/Saghen/blink.cmp), scanning Markdown files in `:pwd` (flat directory).
- Follow `[[note]]` with Enter to open or create `note.md` in `:pwd`.
- Back navigation stack with Backspace after following links.
- Backlinks search into the quickfix list using [`ripgrep`](https://github.com/BurntSushi/ripgrep).

## Installation

### Pre-requisites

- [`blink.cmp`](https://github.com/Saghen/blink.cmp)
- [`ripgrep`](https://github.com/BurntSushi/ripgrep)

### Using [`lazy.nvim`](https://github.com/folke/lazy.nvim)

```lua
{
    "Sahel13/notes.nvim",
    ft = "markdown",
    opts = {},
}
```

## Configuration

```lua
opts = {
    mappings = {
        follow = "<CR>",
        back = "<BS>",
        backlinks = "<leader>nb",
    },
}
```

Set any mapping to `false` to disable it. If you disable the backlinks mapping, you can still run `:lua require("notes").find_backlinks()`.
