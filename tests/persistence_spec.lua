local tab    = require("fret.tab")
local config = require("fret.config")
local editor = require("fret.editor")

describe("persistence", function()
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    config.setup({ fret_dir = dir })
  end)

  after_each(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_option(buf, "filetype") == "fret" then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
    vim.fn.delete(dir, "rf")
  end)

  local function write_fret(path, song)
    local f = io.open(path, "w")
    f:write(vim.json.encode(song))
    f:close()
  end

  -- ── FretSave ──────────────────────────────────────────────────────────────

  describe("FretSave", function()
    it("writes a .fret file to fret_dir", function()
      local song = tab.new({ title = "My Riff", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/My Riff.fret", song)
      editor.open_file(dir .. "/My Riff.fret")
      vim.cmd("FretSave")
      assert.equals(1, vim.fn.filereadable(dir .. "/My Riff.fret"))
    end)

    it("filename is derived from the song title", function()
      local song = tab.new({ title = "Cool Riff", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/Cool Riff.fret", song)
      editor.open_file(dir .. "/Cool Riff.fret")
      vim.cmd("FretSave")
      assert.equals(1, vim.fn.filereadable(dir .. "/Cool Riff.fret"))
    end)

    it("saved file contains valid JSON with the title", function()
      local song = tab.new({ title = "JSON Test", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/JSON Test.fret", song)
      editor.open_file(dir .. "/JSON Test.fret")
      vim.cmd("FretSave")
      local f = io.open(dir .. "/JSON Test.fret", "r")
      local content = f:read("*a")
      f:close()
      local ok, decoded = pcall(vim.json.decode, content)
      assert.truthy(ok)
      assert.equals("JSON Test", decoded.title)
    end)

    it("creates fret_dir automatically when it does not exist", function()
      local subdir = dir .. "/new"
      config.setup({ fret_dir = subdir })
      local song = tab.new({ title = "New Dir", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/New Dir.fret", song)
      editor.open_file(dir .. "/New Dir.fret")
      vim.cmd("FretSave")
      assert.equals(1, vim.fn.isdirectory(subdir))
      assert.equals(1, vim.fn.filereadable(subdir .. "/New Dir.fret"))
    end)

    it("notifies with the saved path", function()
      local song = tab.new({ title = "Notify Test", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/Notify Test.fret", song)
      editor.open_file(dir .. "/Notify Test.fret")
      local notified = false
      local orig_notify = vim.notify
      vim.notify = function(msg, _) if msg:find("saved") then notified = true end end
      vim.cmd("FretSave")
      vim.notify = orig_notify
      assert.truthy(notified)
    end)
  end)

  -- ── open_file ─────────────────────────────────────────────────────────────

  describe("open_file", function()
    it("opens a buffer whose first line is the song title", function()
      local song = tab.new({ title = "Smoke", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/Smoke.fret", song)
      editor.open_file(dir .. "/Smoke.fret")
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("Smoke", lines[1])
    end)

    it("restores notes visible in the rendered buffer", function()
      local song = tab.new({ title = "Notes", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      tab.set_note(song, 1, 1, 1, 1, 5)
      tab.set_note(song, 1, 1, 1, 2, 4)
      tab.set_note(song, 1, 1, 1, 3, 3)
      write_fret(dir .. "/Notes.fret", song)
      editor.open_file(dir .. "/Notes.fret")
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- e row has fret 5, B row has fret 4, G row has fret 3
      local text = table.concat(lines, "\n")
      assert.truthy(text:find("5", 1, true))
      assert.truthy(text:find("4", 1, true))
      assert.truthy(text:find("3", 1, true))
    end)

    it("restores subtitle, tuning and order visible in the header", function()
      local song = tab.new({ title = "T", subtitle = "Deep Purple", tuning = "Standard", order = "A B" })
      write_fret(dir .. "/T.fret", song)
      editor.open_file(dir .. "/T.fret")
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local text  = table.concat(lines, "\n")
      assert.truthy(text:find("Deep Purple", 1, true))
      assert.truthy(text:find("Standard",    1, true))
      assert.truthy(text:find("Order: A B",  1, true))
    end)

    it("restores section name visible in the rendered header line", function()
      local song = tab.new({ title = "Sec", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      tab.set_section_name(song, 1, "Intro")
      write_fret(dir .. "/Sec.fret", song)
      editor.open_file(dir .. "/Sec.fret")
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local text  = table.concat(lines, "\n")
      assert.truthy(text:find("[Intro]", 1, true))
    end)

    it("restores repeat markers visible in the rendered header line", function()
      local song = tab.new({ title = "Rep", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      tab.toggle_repeat_start(song, 1)
      tab.toggle_repeat_end(song, 1)
      write_fret(dir .. "/Rep.fret", song)
      editor.open_file(dir .. "/Rep.fret")
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local text  = table.concat(lines, "\n")
      assert.truthy(text:find("|:", 1, true))
      assert.truthy(text:find(":|", 1, true))
    end)

    it("notifies an error when the file does not exist", function()
      local errored = false
      local orig_notify = vim.notify
      vim.notify = function(_, level) if level == vim.log.levels.ERROR then errored = true end end
      editor.open_file(dir .. "/does_not_exist.fret")
      vim.notify = orig_notify
      assert.truthy(errored)
    end)

    it("notifies an error when the file contains invalid JSON", function()
      local bad = dir .. "/bad.fret"
      local f = io.open(bad, "w"); f:write("not json at all"); f:close()
      local errored = false
      local orig_notify = vim.notify
      vim.notify = function(_, level) if level == vim.log.levels.ERROR then errored = true end end
      editor.open_file(bad)
      vim.notify = orig_notify
      assert.truthy(errored)
    end)
  end)

  -- ── overwrite protection ──────────────────────────────────────────────────

  describe("overwrite protection", function()
    it("prompts before overwriting a file opened from a different source", function()
      local song = tab.new({ title = "Dupe", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/Dupe.fret", song)
      editor.open({ song = tab.new({ title = "Dupe", time_sig = { num = 4, den = 4 }, subdivision = 1 }) })

      local prompted = false
      local orig_select = vim.ui.select
      vim.ui.select = function(_, _, cb) prompted = true; cb("Cancel") end
      vim.cmd("FretSave")
      vim.ui.select = orig_select

      assert.truthy(prompted)
    end)

    it("does not overwrite when the user cancels the prompt", function()
      local song = tab.new({ title = "Keep", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/Keep.fret", song)
      local mtime = vim.fn.getftime(dir .. "/Keep.fret")

      editor.open({ song = tab.new({ title = "Keep", time_sig = { num = 4, den = 4 }, subdivision = 1 }) })

      local orig_select = vim.ui.select
      vim.ui.select = function(_, _, cb) cb("Cancel") end
      vim.cmd("FretSave")
      vim.ui.select = orig_select

      assert.equals(mtime, vim.fn.getftime(dir .. "/Keep.fret"))
    end)

    it("overwrites when the user confirms", function()
      local song = tab.new({ title = "Replace", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/Replace.fret", song)

      local new_song = tab.new({ title = "Replace", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      tab.set_note(new_song, 1, 1, 1, 1, 7)
      editor.open({ song = new_song })

      local orig_select = vim.ui.select
      vim.ui.select = function(_, _, cb) cb("Overwrite") end
      vim.cmd("FretSave")
      vim.ui.select = orig_select

      local f = io.open(dir .. "/Replace.fret", "r")
      local content = f:read("*a"); f:close()
      local ok, decoded = pcall(vim.json.decode, content)
      assert.truthy(ok)
      assert.equals("Replace", decoded.title)
    end)

    it("saves under the new title when the user renames", function()
      local song = tab.new({ title = "Taken", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/Taken.fret", song)
      editor.open({ song = tab.new({ title = "Taken", time_sig = { num = 4, den = 4 }, subdivision = 1 }) })

      local orig_select = vim.ui.select
      local orig_input  = vim.ui.input
      vim.ui.select = function(_, _, cb) cb("Rename") end
      vim.ui.input  = function(_, cb)    cb("New Name") end
      vim.cmd("FretSave")
      vim.ui.select = orig_select
      vim.ui.input  = orig_input

      assert.equals(1, vim.fn.filereadable(dir .. "/New Name.fret"))
    end)

    it("does not prompt when saving back to the file it was opened from", function()
      local song = tab.new({ title = "Own", time_sig = { num = 4, den = 4 }, subdivision = 1 })
      write_fret(dir .. "/Own.fret", song)
      editor.open_file(dir .. "/Own.fret")

      local prompted = false
      local orig_select = vim.ui.select
      vim.ui.select = function(_, _, cb) prompted = true; cb("Cancel") end
      vim.cmd("FretSave")
      vim.ui.select = orig_select

      assert.is_false(prompted)
      assert.equals(1, vim.fn.filereadable(dir .. "/Own.fret"))
    end)
  end)
end)
