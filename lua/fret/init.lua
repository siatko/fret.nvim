local M = {}

function M.setup(opts)
  require("fret.config").setup(opts)

  local km = require("fret.config").options.keymaps
  if km and km.new_tab then
    vim.keymap.set("n", km.new_tab, function()
      require("fret.editor").open()
    end, { desc = "fret: new tab" })
  end

  vim.api.nvim_create_user_command("FretNew", function()
    require("fret.editor").open()
  end, { desc = "Open a new guitar tab editor" })
end

return M
