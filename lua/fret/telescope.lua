local M = {}

function M.find_tabs()
  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local editor       = require("fret.editor")

  local files, dir = editor.list_tab_files()

  if #files == 0 then
    vim.notify("fret: no saved tabs in " .. dir, vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = "Fret Tabs",
    finder = finders.new_table({
      results = files,
      entry_maker = function(path)
        local name = vim.fn.fnamemodify(path, ":t:r")
        return { value = path, display = name, ordinal = name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        editor.open_file(action_state.get_selected_entry().value)
      end)
      return true
    end,
  }):find()
end

return M
