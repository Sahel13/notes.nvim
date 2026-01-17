# notes.nvim

A small note-taking plugin for Neovim inspired by the Zettelkasten style,
emulating a few core [vimwiki](https://github.com/vimwiki/vimwiki) features.

## Features

- Wiki-link completion for `[[...]]` via
[`blink.cmp`](https://github.com/Saghen/blink.cmp), scanning Markdown files in `:pwd` (flat directory).
- Follow `[[note]]` with Enter to open or create `note.md` in `:pwd`.
- Back navigation stack with Backspace after following links.
- Navigate between wiki-links with Tab (next) and Shift+Tab (previous).
- Backlinks search into the quickfix list using [`ripgrep`](https://github.com/BurntSushi/ripgrep).
- Daily notes with automatic date-based filename (`YYYY-MM-DD.md`) and formatted title.

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
        next_wikilink = "<Tab>",
        prev_wikilink = "<S-Tab>",
        backlinks = "<leader>nb",
        daily_note = "<leader>nd",
    },
}
```

Set any mapping to `false` to disable it. If you disable the backlinks mapping, you can still run `:lua require("notes").find_backlinks()`. Similarly, the daily note function is available as `:lua require("notes").open_daily_note()`.
