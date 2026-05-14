-- Core data model for a guitar tab
local M = {}

-- Create a new empty measure
-- slots[slot_idx][string_idx] = fret_number (integer) or nil
local function new_measure(slots_per_measure)
  local slots = {}
  for i = 1, slots_per_measure do
    slots[i] = {}
  end
  return { slots = slots }
end

-- Create a new song with one empty measure
function M.new(opts)
  opts = opts or {}
  local num = (opts.time_sig and opts.time_sig.num) or 4
  local den = (opts.time_sig and opts.time_sig.den) or 4
  local subdivision = opts.subdivision or 4
  local slots_per_measure = num * subdivision
  return {
    time_sig = { num = num, den = den },
    subdivision = subdivision,
    measures = { new_measure(slots_per_measure) },
  }
end

function M.slots_per_measure(song)
  return song.time_sig.num * song.subdivision
end

-- Get fret at (measure_idx, slot_idx, string_idx); returns nil if empty
function M.get_note(song, mi, si, str)
  local m = song.measures[mi]
  if not m then return nil end
  return m.slots[si] and m.slots[si][str]
end

-- Set or clear a note (fret=nil clears)
function M.set_note(song, mi, si, str, fret)
  local m = song.measures[mi]
  if not m then return end
  if not m.slots[si] then m.slots[si] = {} end
  m.slots[si][str] = fret
end

-- Append a new empty measure
function M.add_measure(song)
  local spm = M.slots_per_measure(song)
  table.insert(song.measures, new_measure(spm))
end

-- Remove measure at index (keeps at least 1)
function M.remove_measure(song, idx)
  if #song.measures <= 1 then return end
  table.remove(song.measures, idx)
end

-- Change time signature; rebuilds all measures (notes are lost)
function M.set_time_sig(song, num, den)
  song.time_sig = { num = num, den = den }
  local spm = M.slots_per_measure(song)
  local new_measures = {}
  for _ = 1, #song.measures do
    table.insert(new_measures, new_measure(spm))
  end
  song.measures = new_measures
end

-- Change subdivision; rebuilds all measures
function M.set_subdivision(song, subdiv)
  song.subdivision = subdiv
  local spm = M.slots_per_measure(song)
  local new_measures = {}
  for _ = 1, #song.measures do
    table.insert(new_measures, new_measure(spm))
  end
  song.measures = new_measures
end

return M
