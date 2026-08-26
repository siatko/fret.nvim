-- Core data model: song → sections → measures → slots → notes
local M = {}

local function new_measure(slots_per_measure)
  local slots = {}
  for i = 1, slots_per_measure do slots[i] = {} end
  return { slots = slots, durations = {} }
end

local function new_section(slots_per_measure)
  return {
    name         = nil,
    repeat_start = false,
    repeat_end   = false,
    measures     = { new_measure(slots_per_measure) },
  }
end

function M.new(opts)
  opts = opts or {}
  local num         = (opts.time_sig and opts.time_sig.num) or 4
  local den         = (opts.time_sig and opts.time_sig.den) or 4
  local subdivision = opts.subdivision or 4
  local spm         = num * subdivision
  return {
    title       = (opts.title    ~= "" and opts.title)    or nil,
    subtitle    = (opts.subtitle ~= "" and opts.subtitle) or nil,
    tuning      = (opts.tuning   ~= "" and opts.tuning)   or nil,
    order       = (opts.order    ~= "" and opts.order)    or nil,
    time_sig    = { num = num, den = den },
    subdivision = subdivision,
    sections    = { new_section(spm) },
  }
end

function M.slots_per_measure(song)
  return song.time_sig.num * song.subdivision
end

function M.get_note(song, sec, mi, si, str)
  local s = song.sections[sec]
  if not s then return nil end
  local m = s.measures[mi]
  if not m then return nil end
  return m.slots[si] and m.slots[si][str]
end

local MAX_FRET = 12

function M.set_note(song, sec, mi, si, str, fret)
  local s = song.sections[sec]
  if not s then return end
  local m = s.measures[mi]
  if not m then return end
  if fret ~= nil and (fret < 0 or fret > MAX_FRET) then return end
  if not m.slots[si] then m.slots[si] = {} end
  m.slots[si][str] = fret
end

function M.add_measure(song, sec)
  local s = song.sections[sec]
  if not s then return end
  table.insert(s.measures, new_measure(M.slots_per_measure(song)))
end

function M.remove_measure(song, sec, mi)
  local s = song.sections[sec]
  if not s or #s.measures <= 1 then return end
  table.remove(s.measures, mi)
end

function M.add_section(song, after_idx)
  local spm = M.slots_per_measure(song)
  table.insert(song.sections, (after_idx or #song.sections) + 1, new_section(spm))
end

function M.remove_section(song, idx)
  if #song.sections <= 1 then return end
  table.remove(song.sections, idx)
end

function M.set_section_name(song, idx, name)
  local s = song.sections[idx]
  if s then s.name = (name and name ~= "") and name or nil end
end

function M.toggle_repeat_start(song, idx)
  local s = song.sections[idx]
  if s then s.repeat_start = not s.repeat_start end
end

function M.default_duration(song)
  return song.time_sig.den * song.subdivision
end

function M.set_duration(song, sec, mi, si, dur)
  local s = song.sections[sec]
  if not s then return end
  local m = s.measures[mi]
  if not m then return end
  if not m.durations then m.durations = {} end
  m.durations[si] = dur
end

function M.toggle_repeat_end(song, idx)
  local s = song.sections[idx]
  if s then s.repeat_end = not s.repeat_end end
end

function M.set_time_sig(song, num, den)
  song.time_sig = { num = num, den = den }
  local spm = M.slots_per_measure(song)
  for _, s in ipairs(song.sections) do
    local new_measures = {}
    for _ = 1, #s.measures do table.insert(new_measures, new_measure(spm)) end
    s.measures = new_measures
  end
end

function M.set_subdivision(song, subdiv)
  song.subdivision = subdiv
  local spm = M.slots_per_measure(song)
  for _, s in ipairs(song.sections) do
    local new_measures = {}
    for _ = 1, #s.measures do table.insert(new_measures, new_measure(spm)) end
    s.measures = new_measures
  end
end

local ARTICULATION_KINDS = { v = true, h = true, p = true, ["/"] = true, ["\\"] = true }
local CONNECT_KINDS      = { h = true, p = true, ["/"] = true, ["\\"] = true }
local DECORATION_KINDS   = { v = true }
local DISPLAY_CHARS      = { v = "~", h = "h", p = "p", ["/"] = "/", ["\\"] = "\\" }

function M.display_char(kind)
  return DISPLAY_CHARS[kind]
end

function M.is_connection(kind)
  return CONNECT_KINDS[kind] == true
end

function M.is_decoration(kind)
  return DECORATION_KINDS[kind] == true
end

function M.set_articulation(song, sec, mi, si, str, kind)
  local s = song.sections[sec]
  if not s then return end
  local m = s.measures[mi]
  if not m then return end

  if kind ~= nil then
    if not ARTICULATION_KINDS[kind] then return end
    if not m.slots[si] or m.slots[si][str] == nil then return end
    if CONNECT_KINDS[kind] then
      local spm = M.slots_per_measure(song)
      if si >= spm then return end
    end
  end

  if not m.articulation then m.articulation = {} end
  if not m.articulation[si] then m.articulation[si] = {} end
  m.articulation[si][str] = kind
end

function M.get_articulation(song, sec, mi, si, str)
  local s = song.sections[sec]
  if not s then return end
  local m = s.measures[mi]
  if not m then return end
  if not m.articulation then return end
  return m.articulation[si] and m.articulation[si][str]
end

return M
