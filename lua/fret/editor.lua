-- Interactive tab editor buffer
local M = {}

local tab_mod = require("fret.tab")
local render  = require("fret.render")
local config  = require("fret.config")

-- State per buffer: keyed by bufnr
local state = {}

local STRINGS = { "e", "B", "G", "D", "A", "E" }

-- ── helpers ──────────────────────────────────────────────────────────────────

local function get_state(bufnr)
  return state[bufnr]
end

-- Re-render and restore cursor to the correct position
local function redraw(bufnr)
  local st = get_state(bufnr)
  if not st then return end

  local lines, pos_map, slot_starts = render.render(st.song)
  st.pos_map    = pos_map
  st.slot_starts = slot_starts

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Place cursor at (st.cur_str+1 row, slot start col)
  local row  = st.cur_str + 1 -- 1-indexed: row 1=ruler, rows 2..7=strings
  local spm  = tab_mod.slots_per_measure(st.song)
  -- clamp cursor measure/slot
  if st.cur_mi > #st.song.measures then
    st.cur_mi = #st.song.measures
  end
  if st.cur_si > spm then st.cur_si = spm end

  local sc = slot_starts[st.cur_mi] and slot_starts[st.cur_mi][st.cur_si]
  if sc then
    -- nvim_win_set_cursor is 1-indexed row, 0-indexed col
    local ok, err = pcall(vim.api.nvim_win_set_cursor, 0, { row, sc - 1 })
    if not ok then
      vim.notify("fret: cursor error: " .. err, vim.log.levels.DEBUG)
    end
  end
end

-- ── cursor movement ───────────────────────────────────────────────────────────

local function move_right(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  local spm = tab_mod.slots_per_measure(st.song)
  st.cur_si = st.cur_si + 1
  if st.cur_si > spm then
    st.cur_si = 1
    st.cur_mi = st.cur_mi + 1
    if st.cur_mi > #st.song.measures then
      st.cur_mi = #st.song.measures
      st.cur_si = spm
    end
  end
  redraw(bufnr)
end

local function move_left(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  st.cur_si = st.cur_si - 1
  if st.cur_si < 1 then
    st.cur_mi = st.cur_mi - 1
    if st.cur_mi < 1 then
      st.cur_mi = 1
      st.cur_si = 1
    else
      st.cur_si = tab_mod.slots_per_measure(st.song)
    end
  end
  redraw(bufnr)
end

local function move_down(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  local n = #(config.options.strings or STRINGS)
  st.cur_str = st.cur_str + 1
  if st.cur_str > n then st.cur_str = n end
  redraw(bufnr)
end

local function move_up(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  st.cur_str = st.cur_str - 1
  if st.cur_str < 1 then st.cur_str = 1 end
  redraw(bufnr)
end

-- ── note entry ────────────────────────────────────────────────────────────────

-- Collect a fret number: user types digits, <Enter> or next move confirms
local function enter_note(bufnr, first_digit)
  local st = get_state(bufnr)
  if not st then return end

  -- Show prompt
  local prompt = "Fret: " .. first_digit
  vim.api.nvim_echo({ { prompt, "Question" } }, false, {})

  local digits = first_digit
  while true do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then break end

    if ch:match("^%d$") then
      digits = digits .. ch
      vim.api.nvim_echo({ { "Fret: " .. digits, "Question" } }, false, {})
    elseif ch == "\r" or ch == "\n" or ch == " " then
      break
    elseif ch == "\27" then -- ESC cancels
      vim.api.nvim_echo({ { "", "Normal" } }, false, {})
      return
    else
      -- non-digit non-enter: treat as end of input
      break
    end
  end

  local fret = tonumber(digits)
  if fret then
    tab_mod.set_note(st.song, st.cur_mi, st.cur_si, st.cur_str, fret)
  end
  vim.api.nvim_echo({ { "", "Normal" } }, false, {})
  redraw(bufnr)
end

local function clear_note(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.set_note(st.song, st.cur_mi, st.cur_si, st.cur_str, nil)
  redraw(bufnr)
end

-- ── measure management ────────────────────────────────────────────────────────

local function add_measure(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.add_measure(st.song)
  st.cur_mi = #st.song.measures
  st.cur_si = 1
  redraw(bufnr)
end

local function delete_measure(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.remove_measure(st.song, st.cur_mi)
  if st.cur_mi > #st.song.measures then
    st.cur_mi = #st.song.measures
  end
  redraw(bufnr)
end

-- ── time sig / subdivision ────────────────────────────────────────────────────

local function set_timesig(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  local input = vim.fn.input("Time signature (e.g. 4/4 or 3/4): ")
  if not input or input == "" then return end
  local num, den = input:match("^(%d+)/(%d+)$")
  num, den = tonumber(num), tonumber(den)
  if not num or not den or den == 0 then
    vim.notify("fret: invalid time signature", vim.log.levels.WARN)
    return
  end
  tab_mod.set_time_sig(st.song, num, den)
  st.cur_mi = 1
  st.cur_si = 1
  redraw(bufnr)
end

local function set_subdivision(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  local input = vim.fn.input("Subdivisions per beat (1=quarter 2=8th 4=16th): ")
  local n = tonumber(input)
  if not n or n < 1 then
    vim.notify("fret: invalid subdivision", vim.log.levels.WARN)
    return
  end
  tab_mod.set_subdivision(st.song, n)
  st.cur_mi = 1
  st.cur_si = 1
  redraw(bufnr)
end

-- ── buffer setup ──────────────────────────────────────────────────────────────

local function setup_keymaps(bufnr)
  local km = config.options.keymaps
  local opts = { buffer = bufnr, nowait = true, silent = true }

  local function map(key, fn)
    vim.keymap.set("n", key, fn, opts)
  end

  map(km.move_left,      function() move_left(bufnr) end)
  map(km.move_right,     function() move_right(bufnr) end)
  map(km.move_up,        function() move_up(bufnr) end)
  map(km.move_down,      function() move_down(bufnr) end)
  map(km.clear_note,     function() clear_note(bufnr) end)
  map(km.add_measure,    function() add_measure(bufnr) end)
  map(km.delete_measure, function() delete_measure(bufnr) end)
  map(km.set_timesig,    function() set_timesig(bufnr) end)
  map(km.set_subdiv,     function() set_subdivision(bufnr) end)

  -- Digit keys trigger note entry
  for d = 0, 9 do
    local digit = tostring(d)
    vim.keymap.set("n", digit, function()
      enter_note(bufnr, digit)
    end, opts)
  end
end

-- ── public API ────────────────────────────────────────────────────────────────

function M.open(opts)
  opts = opts or {}
  local song = opts.song or tab_mod.new({
    time_sig  = config.options.time_sig,
    subdivision = config.options.subdivision,
  })

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, "fret://tab")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "fret")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  state[bufnr] = {
    song    = song,
    cur_mi  = 1, -- current measure index
    cur_si  = 1, -- current slot index
    cur_str = 1, -- current string index (1=e)
    pos_map = {},
    slot_starts = {},
  }

  setup_keymaps(bufnr)

  vim.api.nvim_buf_create_user_command(bufnr, "FretAddMeasure", function()
    add_measure(bufnr)
  end, { desc = "Add a new measure" })

  vim.api.nvim_buf_create_user_command(bufnr, "FretTimeSig", function()
    set_timesig(bufnr)
  end, { desc = "Set time signature" })

  vim.api.nvim_buf_create_user_command(bufnr, "FretSubdiv", function()
    set_subdivision(bufnr)
  end, { desc = "Set subdivision" })

  -- Clean up state when buffer is wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      state[bufnr] = nil
    end,
  })

  vim.api.nvim_set_current_buf(bufnr)
  redraw(bufnr)
end

return M
