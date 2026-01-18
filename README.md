# notes.nvim

A small note-taking plugin for Neovim inspired by the Zettelkasten style,
emulating a few core [vimwiki](https://github.com/vimwiki/vimwiki) features.

## Features

- Wiki-link completion for `[[...]]` via
[`blink.cmp`](https://github.com/Saghen/blink.cmp), scanning Markdown files in `:pwd` (flat directory).
- Follow `[[note]]` with Enter to open or create `note.md` in `:pwd`.
- **Citation support** with `[@key]` syntax (Pandoc-style) and BibTeX integration.
- Citation completion from `.bib` files with author/year metadata.
- Follow `[@key]` to jump to the entry in your bib file.
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

```lua
opts = {
    bib_file = "~/references.bib",  -- Optional: path to your BibTeX file
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

### Citation Setup

To enable citation support, specify the path to your BibTeX file:

```lua
require("notes").setup({
    bib_file = vim.fn.expand("~/documents/references.bib"),
})
```

Then in your Markdown files:
- Type `[@` to trigger citation completion
- Completions show citation keys with author and year
- Press `<CR>` on `[@key]` to open your bib file at that entry
- Press `<BS>` from the bib file to return to your note
