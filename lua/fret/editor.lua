-- Interactive tab editor buffer
local M = {}

local tab_mod = require("fret.tab")
local render  = require("fret.render")
local config  = require("fret.config")

local state    = {}  -- keyed by bufnr
local tab_count = 0
local ns        = vim.api.nvim_create_namespace("fret_cursor")

-- ── state helpers ─────────────────────────────────────────────────────────────

local function get_state(bufnr) return state[bufnr] end

local function cur_section(st)
  return st.song.sections[st.cur_sec]
end

-- ── highlights ────────────────────────────────────────────────────────────────

local function update_highlights(bufnr)
  local st = get_state(bufnr)
  if not st or not st.section_rows[st.cur_sec] then return end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local sc = st.slot_starts[st.cur_sec]
              and st.slot_starts[st.cur_sec][st.cur_mi]
              and st.slot_starts[st.cur_sec][st.cur_mi][st.cur_si]
  local w  = st.slot_widths[st.cur_sec]
              and st.slot_widths[st.cur_sec][st.cur_mi]
              and st.slot_widths[st.cur_sec][st.cur_mi][st.cur_si]
  if not sc or not w then return end

  local col_s = sc - 1      -- 0-indexed start
  local col_e = sc - 1 + w  -- 0-indexed exclusive end

  local rows   = st.section_rows[st.cur_sec]
  local n_str  = #(config.options.strings or { "e", "B", "G", "D", "A", "E" })

  -- beat ruler row
  vim.api.nvim_buf_add_highlight(bufnr, ns, "FretCursorCol", rows.ruler_row - 1, col_s, col_e)

  -- string rows
  for str_idx = 1, n_str do
    local row0 = rows.str_start + str_idx - 2  -- 0-indexed
    local hl   = (str_idx == st.cur_str) and "FretCursorCell" or "FretCursorCol"
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl, row0, col_s, col_e)
  end
end

-- ── redraw ────────────────────────────────────────────────────────────────────

local function redraw(bufnr)
  local st = get_state(bufnr)
  if not st then return end

  local lines, pos_map, slot_starts, slot_widths, section_rows = render.render(st.song)
  st.pos_map      = pos_map
  st.slot_starts  = slot_starts
  st.slot_widths  = slot_widths
  st.section_rows = section_rows

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- clamp cursor
  if st.cur_sec > #st.song.sections then st.cur_sec = #st.song.sections end
  local sec     = cur_section(st)
  local spm     = tab_mod.slots_per_measure(st.song)
  if st.cur_mi > #sec.measures then st.cur_mi = #sec.measures end
  if st.cur_si > spm           then st.cur_si = spm           end

  local rows = section_rows[st.cur_sec]
  local row  = rows.str_start + st.cur_str - 1
  local sc   = slot_starts[st.cur_sec][st.cur_mi][st.cur_si]
  if sc then
    pcall(vim.api.nvim_win_set_cursor, 0, { row, sc - 1 })
  end

  update_highlights(bufnr)
end

-- ── cursor movement ───────────────────────────────────────────────────────────

local function move_right(bufnr)
  local st  = get_state(bufnr)
  if not st then return end
  local spm = tab_mod.slots_per_measure(st.song)
  local sec = cur_section(st)

  st.cur_si = st.cur_si + 1
  if st.cur_si > spm then
    st.cur_si = 1
    st.cur_mi = st.cur_mi + 1
    if st.cur_mi > #sec.measures then
      -- wrap to next section
      if st.cur_sec < #st.song.sections then
        st.cur_sec = st.cur_sec + 1
        st.cur_mi  = 1
      else
        st.cur_mi  = #sec.measures
        st.cur_si  = spm
      end
    end
  end
  redraw(bufnr)
end

local function move_left(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  local spm = tab_mod.slots_per_measure(st.song)

  st.cur_si = st.cur_si - 1
  if st.cur_si < 1 then
    st.cur_mi = st.cur_mi - 1
    if st.cur_mi < 1 then
      -- wrap to previous section
      if st.cur_sec > 1 then
        st.cur_sec = st.cur_sec - 1
        st.cur_mi  = #cur_section(st).measures
        st.cur_si  = spm
      else
        st.cur_mi  = 1
        st.cur_si  = 1
      end
    else
      st.cur_si = spm
    end
  end
  redraw(bufnr)
end

local function move_down(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  local n = #(config.options.strings or { "e", "B", "G", "D", "A", "E" })
  if st.cur_str < n then st.cur_str = st.cur_str + 1 end
  redraw(bufnr)
end

local function move_up(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  if st.cur_str > 1 then st.cur_str = st.cur_str - 1 end
  redraw(bufnr)
end

-- ── note entry ────────────────────────────────────────────────────────────────

local function enter_note(bufnr, first_digit)
  local st = get_state(bufnr)
  if not st then return end

  vim.api.nvim_echo({ { "Fret: " .. first_digit, "Question" } }, false, {})
  local digits = first_digit

  while true do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then break end
    if ch:match("^%d$") then
      digits = digits .. ch
      vim.api.nvim_echo({ { "Fret: " .. digits, "Question" } }, false, {})
    elseif ch == "\27" then
      vim.api.nvim_echo({ { "", "Normal" } }, false, {})
      return
    else
      break
    end
  end

  local fret = tonumber(digits)
  if fret then
    tab_mod.set_note(st.song, st.cur_sec, st.cur_mi, st.cur_si, st.cur_str, fret)
  end
  vim.api.nvim_echo({ { "", "Normal" } }, false, {})
  redraw(bufnr)
end

local function clear_note(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.set_note(st.song, st.cur_sec, st.cur_mi, st.cur_si, st.cur_str, nil)
  redraw(bufnr)
end

-- ── measure management ────────────────────────────────────────────────────────

local function add_measure(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.add_measure(st.song, st.cur_sec)
  st.cur_mi = #cur_section(st).measures
  st.cur_si = 1
  redraw(bufnr)
end

local function delete_measure(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.remove_measure(st.song, st.cur_sec, st.cur_mi)
  if st.cur_mi > #cur_section(st).measures then
    st.cur_mi = #cur_section(st).measures
  end
  redraw(bufnr)
end

-- ── section management ────────────────────────────────────────────────────────

local function add_section(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.add_section(st.song, st.cur_sec)
  st.cur_sec = st.cur_sec + 1
  st.cur_mi  = 1
  st.cur_si  = 1
  redraw(bufnr)
end

local function delete_section(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.remove_section(st.song, st.cur_sec)
  if st.cur_sec > #st.song.sections then
    st.cur_sec = #st.song.sections
  end
  st.cur_mi = 1
  st.cur_si = 1
  redraw(bufnr)
end

local function rename_section(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  local current = cur_section(st).name or ""
  vim.ui.input({ prompt = "Section name (empty to clear): ", default = current }, function(input)
    if input == nil then return end
    tab_mod.set_section_name(st.song, st.cur_sec, input)
    redraw(bufnr)
  end)
end

local function next_section(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  if st.cur_sec < #st.song.sections then
    st.cur_sec = st.cur_sec + 1
    st.cur_mi  = 1
    st.cur_si  = 1
    redraw(bufnr)
  end
end

local function prev_section(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  if st.cur_sec > 1 then
    st.cur_sec = st.cur_sec - 1
    st.cur_mi  = 1
    st.cur_si  = 1
    redraw(bufnr)
  end
end

local function toggle_repeat_start(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.toggle_repeat_start(st.song, st.cur_sec)
  redraw(bufnr)
end

local function toggle_repeat_end(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  tab_mod.toggle_repeat_end(st.song, st.cur_sec)
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
  st.cur_sec = 1; st.cur_mi = 1; st.cur_si = 1
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
  st.cur_sec = 1; st.cur_mi = 1; st.cur_si = 1
  redraw(bufnr)
end

-- ── song metadata ────────────────────────────────────────────────────────────

local function edit_title(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  vim.ui.input({ prompt = "Title: ", default = st.song.title or "" }, function(input)
    if input == nil then return end
    st.song.title = input ~= "" and input or nil
    redraw(bufnr)
  end)
end

local function edit_subtitle(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  vim.ui.input({ prompt = "Subtitle: ", default = st.song.subtitle or "" }, function(input)
    if input == nil then return end
    st.song.subtitle = input ~= "" and input or nil
    redraw(bufnr)
  end)
end

local function edit_order(bufnr)
  local st = get_state(bufnr)
  if not st then return end
  vim.ui.input({ prompt = "Order (e.g. A A B C C): ", default = st.song.order or "" }, function(input)
    if input == nil then return end
    st.song.order = input ~= "" and input or nil
    redraw(bufnr)
  end)
end

-- ── copy to clipboard ─────────────────────────────────────────────────────────

local function copy_tab(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text  = table.concat(lines, "\n")
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  vim.notify("fret: tab copied to clipboard", vim.log.levels.INFO)
end

-- ── keymaps ───────────────────────────────────────────────────────────────────

local function setup_keymaps(bufnr)
  local km   = config.options.keymaps
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
  map(km.copy_tab,       function() copy_tab(bufnr) end)
  map(km.add_section,    function() add_section(bufnr) end)
  map(km.delete_section, function() delete_section(bufnr) end)
  map(km.rename_section, function() rename_section(bufnr) end)
  map(km.repeat_start,   function() toggle_repeat_start(bufnr) end)
  map(km.repeat_end,     function() toggle_repeat_end(bufnr) end)
  map(km.next_section,   function() next_section(bufnr) end)
  map(km.prev_section,   function() prev_section(bufnr) end)
  map(km.edit_title,     function() edit_title(bufnr) end)
  map(km.edit_subtitle,  function() edit_subtitle(bufnr) end)
  map(km.edit_order,     function() edit_order(bufnr) end)

  for d = 0, 9 do
    local digit = tostring(d)
    vim.keymap.set("n", digit, function() enter_note(bufnr, digit) end, opts)
  end
end

-- ── open ─────────────────────────────────────────────────────────────────────

local TIME_SIGS   = { "4/4", "3/4", "2/4", "6/8", "5/4", "7/8", "12/8" }
local SUBDIVISIONS = {
  { label = "4th  (quarter notes)", value = 1 },
  { label = "8th  notes",           value = 2 },
  { label = "16th notes",           value = 4 },
  { label = "32nd notes",           value = 8 },
}

local function open_with_song(song)
  tab_count = tab_count + 1
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, "fret://tab-" .. tab_count)
  vim.api.nvim_buf_set_option(bufnr, "filetype",  "fret")
  vim.api.nvim_buf_set_option(bufnr, "buftype",   "nofile")
  vim.api.nvim_buf_set_option(bufnr, "swapfile",  false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  state[bufnr] = {
    song         = song,
    cur_sec      = 1,
    cur_mi       = 1,
    cur_si       = 1,
    cur_str      = 1,
    pos_map      = {},
    slot_starts  = {},
    slot_widths  = {},
    section_rows = {},
  }

  setup_keymaps(bufnr)

  -- buffer-local commands
  local cmds = {
    FretAddMeasure    = function() add_measure(bufnr) end,
    FretTimeSig       = function() set_timesig(bufnr) end,
    FretSubdiv        = function() set_subdivision(bufnr) end,
    FretCopy          = function() copy_tab(bufnr) end,
    FretAddSection    = function() add_section(bufnr) end,
    FretDeleteSection = function() delete_section(bufnr) end,
    FretRenameSection = function() rename_section(bufnr) end,
    FretTitle         = function() edit_title(bufnr) end,
    FretSubtitle      = function() edit_subtitle(bufnr) end,
    FretOrder         = function() edit_order(bufnr) end,
  }
  for name, fn in pairs(cmds) do
    vim.api.nvim_buf_create_user_command(bufnr, name, fn, {})
  end

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer   = bufnr,
    once     = true,
    callback = function() state[bufnr] = nil end,
  })

  vim.api.nvim_set_current_buf(bufnr)
  redraw(bufnr)
end

function M.open(opts)
  if opts and opts.song then
    open_with_song(opts.song)
    return
  end

  -- Step 1: title (optional, <Enter> to skip)
  vim.ui.input({ prompt = "Title (optional): " }, function(title)
    if title == nil then return end  -- ESC = cancel entirely

    -- Step 2: subtitle (optional)
    vim.ui.input({ prompt = "Subtitle (optional): " }, function(subtitle)
      if subtitle == nil then return end

      -- Step 3: time signature
      local ts_items = vim.list_extend(vim.deepcopy(TIME_SIGS), { "Custom…" })
      vim.ui.select(ts_items, { prompt = "Time signature:" }, function(choice)
        if not choice then return end

        local function proceed(ts_str)
          local num, den = ts_str:match("^(%d+)/(%d+)$")
          num, den = tonumber(num), tonumber(den)
          if not num or not den or den == 0 then
            vim.notify("fret: invalid time signature", vim.log.levels.WARN)
            return
          end

          -- Step 4: smallest note
          local subdiv_labels = {}
          for _, s in ipairs(SUBDIVISIONS) do table.insert(subdiv_labels, s.label) end
          vim.ui.select(subdiv_labels, { prompt = "Smallest note:" }, function(subdiv_choice)
            if not subdiv_choice then return end
            local subdivision = 1
            for _, s in ipairs(SUBDIVISIONS) do
              if s.label == subdiv_choice then subdivision = s.value; break end
            end
            open_with_song(tab_mod.new({
              title       = title,
              subtitle    = subtitle,
              time_sig    = { num = num, den = den },
              subdivision = subdivision,
            }))
          end)
        end

        if choice == "Custom…" then
          vim.ui.input({ prompt = "Time signature (e.g. 5/4): " }, function(input)
            if input and input ~= "" then proceed(input) end
          end)
        else
          proceed(choice)
        end
      end)
    end)
  end)
end

return M
