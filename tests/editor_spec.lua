local tab    = require("fret.tab")
local config = require("fret.config")
local editor = require("fret.editor")

describe("editor", function()
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    config.setup({ fret_dir = dir })
  end)

  after_each(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_get_option_value("filetype", { buf = buf }) == "fret" then
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

  local function open_test_song(title)
    title = title or "Test Tab"
    local song = tab.new({ title = title, time_sig = { num = 4, den = 4 }, subdivision = 1 })
    local path = dir .. "/" .. title .. ".fret"
    write_fret(path, song)
    editor.open_file(path)
    return song, path
  end

  -- ── buffer properties ─────────────────────────────────────────────────────

  describe("buffer properties", function()
    it("filetype is fret", function()
      open_test_song()
      assert.equals("fret", vim.api.nvim_get_option_value("filetype", { buf = 0 }))
    end)

    it("buffer is not directly modifiable", function()
      open_test_song()
      assert.is_false(vim.api.nvim_get_option_value("modifiable", { buf = 0 }))
    end)

    it("buffer name follows the fret:// scheme", function()
      open_test_song("My Riff")
      local name = vim.api.nvim_buf_get_name(0)
      assert.truthy(name:match("^fret://tab%-"), "expected fret://tab-N, got: " .. name)
    end)

    it("first buffer line is the title", function()
      open_test_song("Song Title")
      local lines = vim.api.nvim_buf_get_lines(0, 0, 1, false)
      assert.equals("Song Title", lines[1])
    end)

    it("buffer contains the time signature in the ruler line", function()
      open_test_song()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local text  = table.concat(lines, "\n")
      assert.truthy(text:find("4/4", 1, true))
    end)

    it("buffer contains all six string labels", function()
      open_test_song()
      local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      for _, s in ipairs({ "e", "B", "G", "D", "A", "E" }) do
        assert.truthy(text:find(s, 1, true), "missing string label: " .. s)
      end
    end)

    it("buffer contains a bar numbers line immediately above the ruler", function()
      open_test_song()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local ruler_row
      for i, l in ipairs(lines) do
        if l:match("^4/4") then ruler_row = i; break end
      end
      assert.truthy(ruler_row, "ruler line not found in buffer")
      local bar_line = lines[ruler_row - 1]
      assert.truthy(bar_line,                     "no line before ruler")
      assert.truthy(bar_line:find("1", 1, true),  "bar number '1' missing from bar line")
      assert.falsy(bar_line:match("^%d+/%d+"),    "bar line must not look like the ruler")
    end)
  end)

  -- ── keymaps ───────────────────────────────────────────────────────────────

  describe("keymaps", function()
    it("navigation keys are bound", function()
      open_test_song()
      local bufnr   = vim.api.nvim_get_current_buf()
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local bound   = {}
      for _, km in ipairs(keymaps) do bound[km.lhs] = true end
      assert.truthy(bound["h"], "h not bound")
      assert.truthy(bound["l"], "l not bound")
      assert.truthy(bound["j"], "j not bound")
      assert.truthy(bound["k"], "k not bound")
    end)

    it("edit keys are bound", function()
      open_test_song()
      local bufnr   = vim.api.nvim_get_current_buf()
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local bound   = {}
      for _, km in ipairs(keymaps) do bound[km.lhs] = true end
      assert.truthy(bound["x"], "x not bound")
      assert.truthy(bound["m"], "m not bound")
      assert.truthy(bound["M"], "M not bound")
      assert.truthy(bound["a"], "a not bound")
      assert.truthy(bound["D"], "D not bound")
    end)

    it("save, copy and quit keys are bound", function()
      open_test_song()
      local bufnr   = vim.api.nvim_get_current_buf()
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local bound   = {}
      for _, km in ipairs(keymaps) do bound[km.lhs] = true end
      assert.truthy(bound["Y"], "Y not bound")
      assert.truthy(bound["W"], "W not bound")
      assert.truthy(bound["q"], "q not bound")
      assert.truthy(bound["?"], "? not bound")
    end)
  end)

  -- ── FretTimeSig / FretSubdiv ──────────────────────────────────────────────

  describe("FretTimeSig", function()
    it("updates the time signature", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig_input = vim.ui.input
      vim.ui.input = function(_, cb) cb("3/4") end
      vim.cmd("FretTimeSig")
      vim.ui.input = orig_input
      local st = editor._get_state(bufnr)
      assert.equals(3, st.song.time_sig.num)
      assert.equals(4, st.song.time_sig.den)
    end)

    it("marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig_input = vim.ui.input
      vim.ui.input = function(_, cb) cb("3/4") end
      vim.cmd("FretTimeSig")
      vim.ui.input = orig_input
      assert.is_true(editor._get_state(bufnr).dirty)
    end)

    it("rejects an invalid time signature", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local warned = false
      local orig_input  = vim.ui.input
      local orig_notify = vim.notify
      vim.ui.input = function(_, cb) cb("not/valid") end
      vim.notify   = function(_, lvl) if lvl == vim.log.levels.WARN then warned = true end end
      vim.cmd("FretTimeSig")
      vim.ui.input = orig_input
      vim.notify   = orig_notify
      assert.truthy(warned)
      assert.equals(4, editor._get_state(bufnr).song.time_sig.num)
    end)
  end)

  describe("FretSubdiv", function()
    it("updates the subdivision", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig_input = vim.ui.input
      vim.ui.input = function(_, cb) cb("2") end
      vim.cmd("FretSubdiv")
      vim.ui.input = orig_input
      assert.equals(2, editor._get_state(bufnr).song.subdivision)
    end)

    it("marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig_input = vim.ui.input
      vim.ui.input = function(_, cb) cb("2") end
      vim.cmd("FretSubdiv")
      vim.ui.input = orig_input
      assert.is_true(editor._get_state(bufnr).dirty)
    end)

    it("rejects an invalid subdivision (zero or less)", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local warned = false
      local orig_input  = vim.ui.input
      local orig_notify = vim.notify
      vim.ui.input = function(_, cb) cb("0") end
      vim.notify   = function(_, lvl) if lvl == vim.log.levels.WARN then warned = true end end
      vim.cmd("FretSubdiv")
      vim.ui.input = orig_input
      vim.notify   = orig_notify
      assert.truthy(warned)
      assert.equals(1, editor._get_state(bufnr).song.subdivision)
    end)
  end)

  -- ── FretCopy ──────────────────────────────────────────────────────────────

  describe("FretCopy", function()
    it("puts content wrapped in a fret code block in registers", function()
      open_test_song()
      vim.cmd("FretCopy")
      local text = vim.fn.getreg('"')
      assert.truthy(text:match("^```fret\n"), "should start with ```fret")
      assert.truthy(text:match("\n```$"),     "should end with ```")
    end)

    it("copied content contains the song title", function()
      open_test_song("Clip Song")
      vim.cmd("FretCopy")
      assert.truthy(vim.fn.getreg('"'):find("Clip Song", 1, true))
    end)

    it("copied content matches the buffer content", function()
      open_test_song()
      vim.cmd("FretCopy")
      local text  = vim.fn.getreg('"')
      local inner = text:match("^```fret\n(.*)\n```$")
      local buf   = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      assert.equals(buf, inner)
    end)

    it("saves the file to disk", function()
      open_test_song("Copy Save")
      vim.cmd("FretCopy")
      assert.equals(1, vim.fn.filereadable(dir .. "/Copy Save.fret"))
    end)

    it("also copies to the unnamed register", function()
      open_test_song()
      vim.cmd("FretCopy")
      assert.truthy(vim.fn.getreg('"'):match("^```fret"))
    end)
  end)

  -- ── dirty flag ────────────────────────────────────────────────────────────

  describe("dirty flag", function()
    it("is false after open_file", function()
      open_test_song()
      local st = editor._get_state(vim.api.nvim_get_current_buf())
      assert.is_false(st.dirty)
    end)

    it("is true after adding a measure", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddMeasure")
      local st = editor._get_state(bufnr)
      assert.is_true(st.dirty)
    end)

    it("is true after adding a section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      assert.is_true(st.dirty)
    end)

    it("is false after FretSave", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddMeasure")
      assert.is_true(editor._get_state(bufnr).dirty)
      vim.cmd("FretSave")
      assert.is_false(editor._get_state(bufnr).dirty)
    end)

    it("is false after FretCopy (which also saves)", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      assert.is_true(editor._get_state(bufnr).dirty)
      vim.cmd("FretCopy")
      assert.is_false(editor._get_state(bufnr).dirty)
    end)
  end)
end)
