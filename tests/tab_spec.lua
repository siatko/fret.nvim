local tab = require("fret.tab")

describe("tab data model", function()
  it("creates a song with one empty measure", function()
    local song = tab.new({ time_sig = { num = 4, den = 4 }, subdivision = 4 })
    assert.equals(4, song.time_sig.num)
    assert.equals(4, song.time_sig.den)
    assert.equals(1, #song.measures)
    assert.equals(16, tab.slots_per_measure(song)) -- 4 beats * 4 subdivisions
  end)

  it("sets and gets a note", function()
    local song = tab.new()
    tab.set_note(song, 1, 1, 1, 5) -- measure 1, slot 1, string e, fret 5
    assert.equals(5, tab.get_note(song, 1, 1, 1))
    assert.is_nil(tab.get_note(song, 1, 1, 2))
  end)

  it("clears a note with nil", function()
    local song = tab.new()
    tab.set_note(song, 1, 1, 1, 7)
    tab.set_note(song, 1, 1, 1, nil)
    assert.is_nil(tab.get_note(song, 1, 1, 1))
  end)

  it("adds a measure", function()
    local song = tab.new()
    tab.add_measure(song)
    assert.equals(2, #song.measures)
  end)

  it("does not remove the last measure", function()
    local song = tab.new()
    tab.remove_measure(song, 1)
    assert.equals(1, #song.measures)
  end)

  it("removes a measure when more than one exists", function()
    local song = tab.new()
    tab.add_measure(song)
    tab.remove_measure(song, 1)
    assert.equals(1, #song.measures)
  end)
end)

describe("render", function()
  local render = require("fret.render")
  local config = require("fret.config")
  config.setup({})

  it("produces correct number of lines (ruler + 6 strings)", function()
    local song = tab.new({ time_sig = { num = 4, den = 4 }, subdivision = 1 })
    local lines = render.render(song)
    assert.equals(7, #lines) -- 1 ruler + 6 strings
  end)

  it("ruler starts with time sig", function()
    local song = tab.new({ time_sig = { num = 3, den = 4 }, subdivision = 1 })
    local lines = render.render(song)
    assert.truthy(lines[1]:match("^3/4"))
  end)

  it("reflects a placed note in the rendered output", function()
    local song = tab.new({ time_sig = { num = 4, den = 4 }, subdivision = 1 })
    tab.set_note(song, 1, 1, 1, 12) -- string e, slot 1, fret 12
    local lines = render.render(song)
    -- string e is line 2; fret 12 should appear somewhere
    assert.truthy(lines[2]:match("12"))
  end)
end)
