-- Minimal init for headless tests.
local root = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h")
vim.opt.rtp:prepend(root)

local plenary = os.getenv("PLENARY_PATH")
if plenary and plenary ~= "" then
  vim.opt.rtp:prepend(plenary)
end

vim.opt.swapfile = false
vim.opt.shada = ""
vim.opt.writebackup = false
vim.opt.shortmess:append("W")
