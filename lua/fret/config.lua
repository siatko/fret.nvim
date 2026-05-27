local M = {}

M.defaults = {
  subdivision = 4,
  time_sig    = { num = 4, den = 4 },
  strings     = { "e", "B", "G", "D", "A", "E" },
  fret_dir    = vim.fn.expand("~/frets"),
  keymaps = {
    move_left      = "h",
    move_right     = "l",
    move_up        = "k",
    move_down      = "j",
    clear_note     = "x",
    set_duration   = "d",
    add_measure    = "m",
    delete_measure = "M",
    set_timesig    = "t",
    set_subdiv     = "s",
    copy_tab       = "Y",
    save_tab       = "W",
    quit           = "q",
    find_tab       = "<leader>gf",
    add_section    = "a",
    delete_section = "D",
    rename_section = "r",
    repeat_start   = "[",
    repeat_end     = "]",
    next_section   = "<C-j>",
    prev_section   = "<C-k>",
    edit_title     = "T",
    edit_subtitle  = "U",
    edit_tuning    = "G",
    edit_order     = "O",
    help           = "?",
    new_tab        = "<leader>gt",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
