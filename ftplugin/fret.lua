vim.opt_local.number         = false
vim.opt_local.relativenumber = false
vim.opt_local.wrap           = false
vim.opt_local.cursorline     = false -- we handle highlighting ourselves
vim.opt_local.signcolumn     = "no"
vim.opt_local.scrolloff      = 2

-- Slot column across all strings
vim.api.nvim_set_hl(0, "FretCursorCol",  { link = "Visual", default = true })
-- The active cell (current string + current slot)
vim.api.nvim_set_hl(0, "FretCursorCell", { link = "Search", default = true })
