-- Renders all sections into a flat list of lines plus navigation metadata.
--
-- Returns: lines, pos_map, slot_starts, slot_widths, section_rows
--   lines        - flat list of strings (the buffer content)
--   pos_map      - pos_map[abs_row][col] = {sec,mi,si,str}  (1-indexed)
--   slot_starts  - slot_starts[sec][mi][si] = col (1-indexed)
--   slot_widths  - slot_widths[sec][mi][si] = char width
--   section_rows - section_rows[sec] = {header_row, ruler_row, str_start}
local M = {}

local tab    = require("fret.tab")
local config = require("fret.config")

local STRINGS = { "e", "B", "G", "D", "A", "E" }

local function fmt_fret(fret, width)
  if fret == nil then return string.rep("-", width) end
  local s = tostring(fret)
  return string.rep(" ", width - #s) .. s
end

local function beat_label(slot_idx, subdivision)
  local beat_num = math.ceil(slot_idx / subdivision)
  local sub_pos  = (slot_idx - 1) % subdivision + 1
  return sub_pos == 1 and tostring(beat_num) or "."
end

local function measure_col_widths(measure, spm, subdivision)
  local widths = {}
  for si = 1, spm do
    local slot = measure.slots[si] or {}
    -- minimum width must fit the beat label (e.g. "10" is 2 chars wide)
    local w = #beat_label(si, subdivision)
    for _, fret in pairs(slot) do
      local d = #tostring(fret)
      if d > w then w = d end
    end
    widths[si] = w
  end
  return widths
end

local function lpad(s, w)
  return string.rep(" ", w - #s) .. s
end

local function section_header(section)
  local parts = {}
  if section.repeat_start then table.insert(parts, "|:") end
  if section.name and section.name ~= "" then
    table.insert(parts, "[" .. section.name .. "]")
  end
  if section.repeat_end then table.insert(parts, ":|") end
  return #parts > 0 and table.concat(parts, "  ") or "---"
end

function M.render(song)
  local strings     = config.options.strings or STRINGS
  local n_strings   = #strings
  local subdivision = song.subdivision
  local spm         = tab.slots_per_measure(song)

  local max_str_len = 0
  for _, s in ipairs(strings) do
    if #s > max_str_len then max_str_len = #s end
  end
  local ts       = song.time_sig.num .. "/" .. song.time_sig.den
  local prefix_w = math.max(max_str_len, #ts) + 1

  local all_lines    = {}
  local section_rows = {}
  local slot_starts  = {}
  local slot_widths  = {}
  local pos_map      = {}

  -- ── song header block ───────────────────────────────────────────────────────
  local has_header = false
  if song.title and song.title ~= "" then
    table.insert(all_lines, song.title)
    has_header = true
  end
  if song.subtitle and song.subtitle ~= "" then
    table.insert(all_lines, song.subtitle)
    has_header = true
  end
  if song.tuning and song.tuning ~= "" then
    table.insert(all_lines, "Tuning: " .. song.tuning)
    has_header = true
  end
  if song.order and song.order ~= "" then
    table.insert(all_lines, "Order: " .. song.order)
    has_header = true
  end
  if has_header then
    table.insert(all_lines, "")  -- blank separator before sections
  end

  for sec_idx, section in ipairs(song.sections) do
    -- ── header ──────────────────────────────────────────────────────────────
    table.insert(all_lines, section_header(section))
    local header_row = #all_lines

    -- ── ruler + string lines ─────────────────────────────────────────────────
    local ruler = ts .. string.rep(" ", prefix_w - #ts) .. "|"
    local str_lines = {}
    for i = 1, n_strings do
      str_lines[i] = strings[i] .. string.rep(" ", prefix_w - #strings[i]) .. "|"
    end

    slot_starts[sec_idx] = {}
    slot_widths[sec_idx] = {}

    -- col tracks the 1-indexed character position within each line.
    -- After the prefix and the leading "|": position prefix_w + 2.
    local col = prefix_w + 2

    for mi, measure in ipairs(section.measures) do
      local widths = measure_col_widths(measure, spm, subdivision)
      slot_starts[sec_idx][mi] = {}
      slot_widths[sec_idx][mi] = {}

      -- Each measure segment: " " + (slot + " ") * spm + "|"
      local seg_ruler = " "
      local seg_strs  = {}
      for i = 1, n_strings do seg_strs[i] = " " end

      col = col + 1  -- leading " " of the segment

      for si = 1, spm do
        slot_starts[sec_idx][mi][si] = col
        slot_widths[sec_idx][mi][si] = widths[si]

        seg_ruler = seg_ruler .. lpad(beat_label(si, subdivision), widths[si]) .. " "
        for str_idx = 1, n_strings do
          local fret = measure.slots[si] and measure.slots[si][str_idx]
          seg_strs[str_idx] = seg_strs[str_idx] .. fmt_fret(fret, widths[si]) .. " "
        end

        col = col + widths[si] + 1  -- slot chars + trailing " "
      end

      ruler = ruler .. seg_ruler .. "|"
      for i = 1, n_strings do
        str_lines[i] = str_lines[i] .. seg_strs[i] .. "|"
      end

      col = col + 1  -- closing "|"
    end

    table.insert(all_lines, ruler)
    local ruler_row = #all_lines

    local str_start = #all_lines + 1
    for i = 1, n_strings do
      table.insert(all_lines, str_lines[i])
    end

    section_rows[sec_idx] = {
      header_row = header_row,
      ruler_row  = ruler_row,
      str_start  = str_start,
    }

    -- ── pos_map ──────────────────────────────────────────────────────────────
    for mi = 1, #section.measures do
      for si = 1, spm do
        local sc = slot_starts[sec_idx][mi][si]
        local w  = slot_widths[sec_idx][mi][si]
        for str_idx = 1, n_strings do
          local row = str_start + str_idx - 1
          pos_map[row] = pos_map[row] or {}
          for c = sc, sc + w - 1 do
            pos_map[row][c] = { sec = sec_idx, mi = mi, si = si, str = str_idx }
          end
        end
      end
    end

    -- blank line between sections
    if sec_idx < #song.sections then
      table.insert(all_lines, "")
    end
  end

  return all_lines, pos_map, slot_starts, slot_widths, section_rows
end

return M
