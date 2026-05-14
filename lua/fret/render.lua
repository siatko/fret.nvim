-- Renders a song (from tab.lua) into a list of display lines + a position map.
-- Position map: pos_map[row][col] = {mi=measure_idx, si=slot_idx, str=string_idx}
--   row 0 = beat header (not navigable)
--   rows 1..6 = strings e,B,G,D,A,E
local M = {}

local tab = require("fret.tab")
local config = require("fret.config")

local STRINGS = { "e", "B", "G", "D", "A", "E" }

-- Returns display string for a fret number (nil -> "-")
local function fmt_fret(fret, width)
  if fret == nil then
    return string.rep("-", width)
  end
  local s = tostring(fret)
  -- right-pad to width
  return s .. string.rep("-", width - #s)
end

-- Compute the column width needed for each slot in a measure
-- (max fret digits across all strings at that slot, minimum 1)
local function measure_col_widths(measure)
  local widths = {}
  for si, slot in ipairs(measure.slots) do
    local w = 1
    for _, fret in pairs(slot) do
      local d = #tostring(fret)
      if d > w then w = d end
    end
    widths[si] = w
  end
  return widths
end

-- Build the beat label for a slot position within a measure
-- beat_num (1-based), sub_pos (1=on beat, >1=subdivision tick)
-- subdivision: slots per beat
local function beat_label(slot_idx, subdivision)
  local beat_num = math.ceil(slot_idx / subdivision)
  local sub_pos  = (slot_idx - 1) % subdivision + 1
  if sub_pos == 1 then
    return tostring(beat_num)
  else
    return "."
  end
end

-- Left-pad a string to width
local function lpad(s, w)
  return string.rep(" ", w - #s) .. s
end

function M.render(song)
  local strings = config.options.strings or STRINGS
  local n_strings = #strings
  local subdivision = song.subdivision
  local spm = tab.slots_per_measure(song)

  -- prefix width: "  e  " style; find max string name length
  local max_str_len = 0
  for _, s in ipairs(strings) do
    if #s > max_str_len then max_str_len = #s end
  end
  local prefix_w = max_str_len + 1 -- "e " or "E "

  -- time sig header prefix (same width as string prefix)
  local ts = song.time_sig.num .. "/" .. song.time_sig.den
  local header_prefix = ts .. string.rep(" ", prefix_w - #ts)

  -- Build per-measure data: col_widths, rendered beat header segment, rendered string segments
  local measure_headers = {}  -- list of strings (beat ruler segment per measure)
  local measure_strings = {}  -- measure_strings[mi][str_idx] = string segment

  for mi, measure in ipairs(song.measures) do
    local widths = measure_col_widths(measure)
    local header_seg = " "
    local str_segs = {}
    for i = 1, n_strings do str_segs[i] = " " end

    for si = 1, spm do
      local w = widths[si]
      local lbl = beat_label(si, subdivision)
      header_seg = header_seg .. lpad(lbl, w) .. " "
      for str_idx = 1, n_strings do
        local fret = measure.slots[si] and measure.slots[si][str_idx]
        str_segs[str_idx] = str_segs[str_idx] .. fmt_fret(fret, w) .. " "
      end
    end

    measure_headers[mi] = header_seg .. "|"
    measure_strings[mi] = {}
    for str_idx = 1, n_strings do
      measure_strings[mi][str_idx] = str_segs[str_idx] .. "|"
    end
  end

  -- Assemble lines
  -- Line 1: beat ruler
  local ruler = header_prefix .. "|"
  for mi = 1, #song.measures do
    ruler = ruler .. measure_headers[mi]
  end

  -- Lines 2..n_strings+1: one per string
  local str_lines = {}
  for str_idx = 1, n_strings do
    local name = strings[str_idx]
    local line = name .. string.rep(" ", prefix_w - #name) .. "|"
    for mi = 1, #song.measures do
      line = line .. measure_strings[mi][str_idx]
    end
    str_lines[str_idx] = line
  end

  local lines = { ruler }
  for _, l in ipairs(str_lines) do
    table.insert(lines, l)
  end

  -- Build position map: pos_map[line_idx][col_idx (1-based)] = {mi,si,str}
  -- line 1 = ruler (not navigable for notes)
  -- lines 2..n+1 = strings
  --
  -- We need to know the byte offset of each slot column within each measure segment.
  -- Re-compute per measure the starting col of each slot in the assembled line.
  local pos_map = {}
  for row = 1, n_strings + 1 do
    pos_map[row] = {}
  end

  -- Compute col offsets of each slot in the final line
  -- prefix_w + 1 (for '|') = start of first measure content
  -- within a measure: " " (1 char) then slot_1_width chars then " " ... repeat
  -- but let's just walk character by character using widths

  local function build_slot_col_map()
    -- Returns: slot_starts[mi][si] = column index (1-based) of the first char of the slot
    local slot_starts = {}
    local col = prefix_w + 1 + 1 -- after "prefix|"
    for mi, measure in ipairs(song.measures) do
      local widths = measure_col_widths(measure)
      slot_starts[mi] = {}
      col = col + 1 -- the leading " " of the measure segment
      for si = 1, spm do
        slot_starts[mi][si] = col
        col = col + widths[si] + 1 -- slot + trailing " "
      end
      col = col + 1 -- the closing "|"
    end
    return slot_starts
  end

  local slot_starts = build_slot_col_map()

  for mi = 1, #song.measures do
    local widths = measure_col_widths(song.measures[mi])
    for si = 1, spm do
      local sc = slot_starts[mi][si]
      local w  = widths[si]
      for str_idx = 1, n_strings do
        local row = str_idx + 1 -- +1 because row 1 is ruler
        for c = sc, sc + w - 1 do
          pos_map[row][c] = { mi = mi, si = si, str = str_idx }
        end
      end
    end
  end

  return lines, pos_map, slot_starts
end

return M
