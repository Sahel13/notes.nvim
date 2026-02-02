# notes.nvim

A small note-taking plugin for Neovim inspired by the Zettelkasten style,
emulating a few core [vimwiki](https://github.com/vimwiki/vimwiki) features.

## Features

- Wiki-link completion for `[[...]]` via
[`blink.cmp`](https://github.com/Saghen/blink.cmp), scanning Markdown files in `:pwd`
and `:pwd/references`.
- Follow `[[note]]` with Enter to open or create `note.md` in `:pwd`.
- Open wiki-links or citations in a split (Shift+Enter) or vertical split (Ctrl+Enter).
- Citation support with `[@key]` syntax (Pandoc-style) and BibTeX integration.
- Citation completion from `.bib` files with author/year metadata.
- Follow `[@key]` to jump to the entry in your bib file.
- Create reference notes from BibTeX entries in `:pwd/references` (Telescope picker with bib preview,
`vim.ui.select` fallback).
- Back navigation stack with Backspace after following links.
- Navigate between wiki-links with Tab (next) and Shift+Tab (previous).
- Backlinks search into the quickfix list using [`ripgrep`](https://github.com/BurntSushi/ripgrep).
- Daily notes with automatic date-based filename (`YYYY-MM-DD.md`) and formatted title.

## Installation

### Prerequisites

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

Register the source in your `blink.cmp` configuration:

```lua
{
    "saghen/blink.cmp",
    opts = {
        sources = {
            default = { "lsp", "path", "snippets", "buffer", "notes" },
            providers = {
                notes = {
                    name = "notes",
                    module = "notes",
                },
            },
        },
    },
}
```

## Configuration

The full configuration with default keybindings is given below.

```lua
opts = {
    bib_file = "~/references.bib",  -- Optional: path to your BibTeX file
    mappings = {
        follow = "<CR>",
        follow_split = "<S-CR>", -- Split and follow wiki-link or citation
        follow_vsplit = "<C-CR>", -- Vertical split and follow wiki-link or citation
        back = "<BS>",
        next_wikilink = "<Tab>",
        prev_wikilink = "<S-Tab>",
        backlinks = "<leader>nb",
        daily_note = "<leader>nd",
        reference_note = "<leader>nr",
    },
}
```

Set any mapping to `false` to disable it.
