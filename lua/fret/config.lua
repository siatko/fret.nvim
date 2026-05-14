local M = {}

M.defaults = {
  subdivision = 4,
  time_sig    = { num = 4, den = 4 },
  strings     = { "e", "B", "G", "D", "A", "E" },
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
    add_section    = "a",
    delete_section = "D",
    rename_section = "r",
    repeat_start   = "[",
    repeat_end     = "]",
    next_section   = "}",
    prev_section   = "{",
    edit_title     = "T",
    edit_subtitle  = "U",
    edit_order     = "O",
    new_tab        = "<leader>gt",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
