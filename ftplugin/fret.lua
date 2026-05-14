vim.opt_local.number         = false
vim.opt_local.relativenumber = false
vim.opt_local.wrap           = false
vim.opt_local.cursorline     = false -- we handle highlighting ourselves
vim.opt_local.signcolumn     = "no"
vim.opt_local.scrolloff      = 2

-- Slot column across all strings (links to CursorLine, always has a bg in any theme)
vim.api.nvim_set_hl(0, "FretCursorCol",  { link = "CursorLine" })
-- The active cell — IncSearch is bright and visible in every colorscheme
vim.api.nvim_set_hl(0, "FretCursorCell", { link = "IncSearch" })
