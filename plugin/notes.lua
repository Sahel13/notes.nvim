local group = vim.api.nvim_create_augroup("notes.nvim", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "markdown",
  callback = function(event)
    vim.keymap.set("n", "<CR>", function()
      local notes = require("notes")
      if not notes.follow_wikilink() then
        vim.cmd("normal! \\<CR>")
      end
    end, { buffer = event.buf, silent = true, desc = "Follow wiki-link" })
  end,
})
