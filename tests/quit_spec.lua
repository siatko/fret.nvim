local tab    = require("fret.tab")
local config = require("fret.config")
local editor = require("fret.editor")

describe("quit editor", function()
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
    title = title or "Quit Test"
    local song = tab.new({ title = title, time_sig = { num = 4, den = 4 }, subdivision = 1 })
    local path = dir .. "/" .. title .. ".fret"
    write_fret(path, song)
    editor.open_file(path)
    return song, path
  end

  local function press_q(bufnr)
    for _, km in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
      if km.lhs == "q" and km.callback then
        km.callback()
        return
      end
    end
  end

  -- ── clean buffer ─────────────────────────────────────────────────────────────

  it("deletes the buffer immediately when clean (no prompt shown)", function()
    open_test_song()
    local bufnr  = vim.api.nvim_get_current_buf()
    local prompted = false
    local orig = vim.ui.select
    vim.ui.select = function(_, _, cb) prompted = true; cb("Cancel") end
    press_q(bufnr)
    vim.ui.select = orig
    assert.is_false(prompted)
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
  end)

  -- ── dirty buffer ─────────────────────────────────────────────────────────────

  it("shows a prompt when the buffer is dirty", function()
    open_test_song()
    local bufnr  = vim.api.nvim_get_current_buf()
    vim.cmd("FretAddMeasure")
    local prompted = false
    local orig = vim.ui.select
    vim.ui.select = function(_, _, cb) prompted = true; cb("Cancel") end
    press_q(bufnr)
    vim.ui.select = orig
    assert.is_true(prompted)
  end)

  it("Cancel: buffer remains open", function()
    open_test_song()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.cmd("FretAddMeasure")
    local orig = vim.ui.select
    vim.ui.select = function(_, _, cb) cb("Cancel") end
    press_q(bufnr)
    vim.ui.select = orig
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
  end)

  it("Quit without saving: deletes the buffer without writing", function()
    open_test_song("No Save")
    local bufnr  = vim.api.nvim_get_current_buf()
    local mtime  = vim.fn.getftime(dir .. "/No Save.fret")
    vim.cmd("FretAddMeasure")
    local orig = vim.ui.select
    vim.ui.select = function(_, _, cb) cb("Quit without saving") end
    press_q(bufnr)
    vim.ui.select = orig
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
    assert.equals(mtime, vim.fn.getftime(dir .. "/No Save.fret"))  -- file unchanged
  end)

  it("Save and quit: saves the file and deletes the buffer", function()
    open_test_song("Save Quit")
    local bufnr = vim.api.nvim_get_current_buf()
    vim.cmd("FretAddMeasure")
    local orig = vim.ui.select
    vim.ui.select = function(_, _, cb) cb("Save and quit") end
    press_q(bufnr)
    vim.ui.select = orig
    assert.equals(1, vim.fn.filereadable(dir .. "/Save Quit.fret"))
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
  end)

  -- ── no title edge cases ──────────────────────────────────────────────────────

  it("Save and quit with no title: prompts for a title before saving", function()
    editor.open({ song = tab.new({ time_sig = { num = 4, den = 4 }, subdivision = 1 }) })
    local bufnr = vim.api.nvim_get_current_buf()
    vim.cmd("FretAddMeasure")
    local title_prompted = false
    local orig_select = vim.ui.select
    local orig_input  = vim.ui.input
    vim.ui.select = function(_, _, cb) cb("Save and quit") end
    vim.ui.input  = function(_, cb) title_prompted = true; cb("Untitled Riff") end
    press_q(bufnr)
    vim.ui.select = orig_select
    vim.ui.input  = orig_input
    assert.is_true(title_prompted)
    assert.equals(1, vim.fn.filereadable(dir .. "/Untitled Riff.fret"))
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
  end)

  it("Save and quit with no title: cancelling the title prompt leaves buffer open", function()
    editor.open({ song = tab.new({ time_sig = { num = 4, den = 4 }, subdivision = 1 }) })
    local bufnr = vim.api.nvim_get_current_buf()
    vim.cmd("FretAddMeasure")
    local orig_select = vim.ui.select
    local orig_input  = vim.ui.input
    vim.ui.select = function(_, _, cb) cb("Save and quit") end
    vim.ui.input  = function(_, cb) cb(nil) end  -- user cancelled title prompt
    press_q(bufnr)
    vim.ui.select = orig_select
    vim.ui.input  = orig_input
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
  end)

  it("Save and quit with no title: empty title leaves buffer open with a warning", function()
    editor.open({ song = tab.new({ time_sig = { num = 4, den = 4 }, subdivision = 1 }) })
    local bufnr = vim.api.nvim_get_current_buf()
    vim.cmd("FretAddMeasure")
    local warned = false
    local orig_select = vim.ui.select
    local orig_input  = vim.ui.input
    local orig_notify = vim.notify
    vim.ui.select = function(_, _, cb) cb("Save and quit") end
    vim.ui.input  = function(_, cb) cb("") end  -- empty title
    vim.notify    = function(_, lvl) if lvl == vim.log.levels.WARN then warned = true end end
    press_q(bufnr)
    vim.ui.select = orig_select
    vim.ui.input  = orig_input
    vim.notify    = orig_notify
    assert.is_true(warned)
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
  end)
end)
