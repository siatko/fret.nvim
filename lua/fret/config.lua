local M = {}

M.defaults = {
  subdivision = 4, -- slots per beat: 1=quarter, 2=8th, 4=16th
  time_sig = { num = 4, den = 4 },
  strings = { "e", "B", "G", "D", "A", "E" },
  slot_width = 2, -- chars per slot column (fret + separator)
  keymaps = {
    move_left      = "h",
    move_right     = "l",
    move_up        = "k",
    move_down      = "j",
    clear_note     = "x",
    add_measure    = "m",
    delete_measure = "M",
    set_timesig    = "t",
    set_subdiv     = "s",
    copy_tab       = "Y",
    new_tab        = "<leader>gt",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
