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

  vim.api.nvim_create_user_command("FretOpen", function(args)
    local editor = require("fret.editor")
    local cfg    = require("fret.config")
    if args.args ~= "" then
      editor.open_file(vim.fn.expand(args.args))
      return
    end
    local dir   = vim.fn.expand(cfg.options.fret_dir or "~/frets")
    local files = vim.fn.glob(dir .. "/*.fret", false, true)
    if #files == 0 then
      vim.notify("fret: no saved tabs in " .. dir, vim.log.levels.WARN)
      return
    end
    local names = vim.tbl_map(function(p) return vim.fn.fnamemodify(p, ":t:r") end, files)
    vim.ui.select(names, { prompt = "Open tab:" }, function(_, idx)
      if not idx then return end
      editor.open_file(files[idx])
    end)
  end, { desc = "Open a saved fret tab", nargs = "?" })
end

return M
