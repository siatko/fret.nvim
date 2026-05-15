local tab    = require("fret.tab")
local config = require("fret.config")
local editor = require("fret.editor")

describe("editor actions", function()
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

  -- 4/4 sub=1 → spm=4; simple, predictable slot counts
  local function open_test_song(title)
    title = title or "Test Tab"
    local song = tab.new({ title = title, time_sig = { num = 4, den = 4 }, subdivision = 1 })
    local path = dir .. "/" .. title .. ".fret"
    write_fret(path, song)
    editor.open_file(path)
    return song, path
  end

  -- Invoke a buffer-local normal keymap by lhs, resolving special keys.
  local function press(bufnr, key)
    local nkey = vim.api.nvim_replace_termcodes(key, true, false, true)
    for _, km in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
      local nlhs = vim.api.nvim_replace_termcodes(km.lhs, true, false, true)
      if nlhs == nkey and km.callback then
        km.callback()
        return
      end
    end
  end

  -- ── additional keymap checks ─────────────────────────────────────────────────

  describe("keymaps bound", function()
    it("digit keys 0-9 are all bound", function()
      open_test_song()
      local bufnr  = vim.api.nvim_get_current_buf()
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local bound  = {}
      for _, km in ipairs(keymaps) do bound[km.lhs] = true end
      for d = 0, 9 do
        assert.truthy(bound[tostring(d)], tostring(d) .. " not bound")
      end
    end)

    it("section, metadata and repeat keymaps are bound", function()
      open_test_song()
      local bufnr  = vim.api.nvim_get_current_buf()
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local bound  = {}
      for _, km in ipairs(keymaps) do
        bound[km.lhs] = true
        bound[vim.api.nvim_replace_termcodes(km.lhs, true, false, true)] = true
      end
      for _, k in ipairs({ "t", "s", "r", "[", "]", "T", "U", "G", "O" }) do
        assert.truthy(bound[k], k .. " not bound")
      end
      local cj = vim.api.nvim_replace_termcodes("<C-j>", true, false, true)
      local ck = vim.api.nvim_replace_termcodes("<C-k>", true, false, true)
      assert.truthy(bound[cj], "<C-j> not bound")
      assert.truthy(bound[ck], "<C-k> not bound")
    end)
  end)

  -- ── cursor movement ──────────────────────────────────────────────────────────

  describe("cursor movement", function()
    it("l advances the slot index", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      assert.equals(1, st.cur_si)
      press(bufnr, "l")
      assert.equals(2, st.cur_si)
    end)

    it("l at the end of a measure wraps into the next measure", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddMeasure")
      local st = editor._get_state(bufnr)
      st.cur_si = 4; st.cur_mi = 1
      press(bufnr, "l")
      assert.equals(2, st.cur_mi)
      assert.equals(1, st.cur_si)
    end)

    it("l at the last slot of the last section stays put", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      st.cur_si = 4; st.cur_mi = 1
      press(bufnr, "l")
      assert.equals(1, st.cur_mi)
      assert.equals(4, st.cur_si)
    end)

    it("l wraps to the next section when at the end of its last measure", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      st.cur_sec = 1; st.cur_mi = 1; st.cur_si = 4
      press(bufnr, "l")
      assert.equals(2, st.cur_sec)
      assert.equals(1, st.cur_mi)
      assert.equals(1, st.cur_si)
    end)

    it("h moves back one slot", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      st.cur_si = 3
      press(bufnr, "h")
      assert.equals(2, st.cur_si)
    end)

    it("h at slot 1 of the first section stays put", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      assert.equals(1, st.cur_si)
      press(bufnr, "h")
      assert.equals(1, st.cur_si)
      assert.equals(1, st.cur_mi)
    end)

    it("h from slot 1 of a section wraps to the last slot of the previous section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      assert.equals(2, st.cur_sec)
      assert.equals(1, st.cur_si)
      press(bufnr, "h")
      assert.equals(1,  st.cur_sec)
      assert.equals(1,  st.cur_mi)
      assert.equals(4,  st.cur_si)  -- spm = 4
    end)

    it("j moves down one string", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      assert.equals(1, st.cur_str)
      press(bufnr, "j")
      assert.equals(2, st.cur_str)
    end)

    it("j on the last string (6) stays put", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      st.cur_str = 6
      press(bufnr, "j")
      assert.equals(6, st.cur_str)
    end)

    it("k moves up one string", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      st.cur_str = 3
      press(bufnr, "k")
      assert.equals(2, st.cur_str)
    end)

    it("k on string 1 (e) stays put", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      assert.equals(1, st.cur_str)
      press(bufnr, "k")
      assert.equals(1, st.cur_str)
    end)
  end)

  -- ── section navigation (<C-j> / <C-k>) ──────────────────────────────────────

  describe("section navigation", function()
    it("<C-j> jumps to the next section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      st.cur_sec = 1
      press(bufnr, "<C-j>")
      assert.equals(2, st.cur_sec)
    end)

    it("<C-j> on the last section stays put", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      press(bufnr, "<C-j>")
      assert.equals(1, st.cur_sec)
    end)

    it("<C-j> resets measure and slot to 1", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      st.cur_sec = 1; st.cur_mi = 1; st.cur_si = 3
      press(bufnr, "<C-j>")
      assert.equals(1, st.cur_mi)
      assert.equals(1, st.cur_si)
    end)

    it("<C-k> jumps to the previous section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      assert.equals(2, st.cur_sec)
      press(bufnr, "<C-k>")
      assert.equals(1, st.cur_sec)
    end)

    it("<C-k> on section 1 stays put", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      press(bufnr, "<C-k>")
      assert.equals(1, st.cur_sec)
    end)

    it("<C-k> resets measure and slot to 1", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      assert.equals(2, st.cur_sec)
      press(bufnr, "<C-k>")
      assert.equals(1, st.cur_mi)
      assert.equals(1, st.cur_si)
    end)
  end)

  -- ── clear_note (x) ───────────────────────────────────────────────────────────

  describe("clear_note (x)", function()
    it("clears the note at the current cursor position", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      tab.set_note(st.song, 1, 1, 1, 1, 7)
      press(bufnr, "x")
      assert.is_nil(tab.get_note(st.song, 1, 1, 1, 1))
    end)

    it("marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      tab.set_note(st.song, 1, 1, 1, 1, 7)
      press(bufnr, "x")
      assert.is_true(st.dirty)
    end)

    it("clearing an already-empty slot still marks dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      press(bufnr, "x")
      assert.is_true(editor._get_state(bufnr).dirty)
    end)
  end)

  -- ── delete_measure (M) ───────────────────────────────────────────────────────

  describe("delete_measure (M)", function()
    it("removes a measure when more than one exists", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddMeasure")
      local st = editor._get_state(bufnr)
      assert.equals(2, #st.song.sections[1].measures)
      press(bufnr, "M")
      assert.equals(1, #st.song.sections[1].measures)
    end)

    it("marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddMeasure")
      local st = editor._get_state(bufnr)
      st.dirty = false
      press(bufnr, "M")
      assert.is_true(st.dirty)
    end)

    it("does not remove the last measure", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      press(bufnr, "M")
      assert.equals(1, #st.song.sections[1].measures)
    end)

    it("clamps cur_mi when the deleted measure was the last", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddMeasure")
      local st = editor._get_state(bufnr)
      st.cur_mi = 2
      press(bufnr, "M")
      assert.equals(1, st.cur_mi)
    end)
  end)

  -- ── delete_section (D) ───────────────────────────────────────────────────────

  describe("delete_section (D)", function()
    it("removes a section when more than one exists", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      assert.equals(2, #st.song.sections)
      press(bufnr, "D")
      assert.equals(1, #st.song.sections)
    end)

    it("marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      st.dirty = false
      press(bufnr, "D")
      assert.is_true(st.dirty)
    end)

    it("does not remove the last section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      press(bufnr, "D")
      assert.equals(1, #st.song.sections)
    end)

    it("clamps cur_sec after deleting the last section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      assert.equals(2, st.cur_sec)
      press(bufnr, "D")
      assert.equals(1, st.cur_sec)
    end)
  end)

  -- ── rename_section (FretRenameSection) ───────────────────────────────────────

  describe("rename_section (FretRenameSection)", function()
    it("sets the section name from user input", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("Chorus") end
      vim.cmd("FretRenameSection")
      vim.ui.input = orig
      assert.equals("Chorus", editor._get_state(bufnr).song.sections[1].name)
    end)

    it("clears the name when an empty string is given", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      tab.set_section_name(st.song, 1, "Intro")
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("") end
      vim.cmd("FretRenameSection")
      vim.ui.input = orig
      assert.is_nil(st.song.sections[1].name)
    end)

    it("marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("Verse") end
      vim.cmd("FretRenameSection")
      vim.ui.input = orig
      assert.is_true(editor._get_state(bufnr).dirty)
    end)

    it("does nothing when the prompt is cancelled (nil input)", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb(nil) end
      vim.cmd("FretRenameSection")
      vim.ui.input = orig
      assert.is_false(st.dirty)
      assert.is_nil(st.song.sections[1].name)
    end)
  end)

  -- ── repeat markers ([ / ]) ───────────────────────────────────────────────────

  describe("repeat markers", function()
    it("[ toggles repeat_start on the current section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      assert.is_false(st.song.sections[1].repeat_start)
      press(bufnr, "[")
      assert.is_true(st.song.sections[1].repeat_start)
    end)

    it("] toggles repeat_end on the current section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      assert.is_false(st.song.sections[1].repeat_end)
      press(bufnr, "]")
      assert.is_true(st.song.sections[1].repeat_end)
    end)

    it("[ marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      press(bufnr, "[")
      assert.is_true(editor._get_state(bufnr).dirty)
    end)

    it("] marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      press(bufnr, "]")
      assert.is_true(editor._get_state(bufnr).dirty)
    end)

    it("pressing [ twice toggles repeat_start back off", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      press(bufnr, "[")
      press(bufnr, "[")
      assert.is_false(st.song.sections[1].repeat_start)
    end)

    it("pressing ] twice toggles repeat_end back off", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      press(bufnr, "]")
      press(bufnr, "]")
      assert.is_false(st.song.sections[1].repeat_end)
    end)

    it("repeat markers on a non-first section", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd("FretAddSection")
      local st = editor._get_state(bufnr)
      assert.equals(2, st.cur_sec)
      press(bufnr, "[")
      assert.is_true(st.song.sections[2].repeat_start)
      assert.is_false(st.song.sections[1].repeat_start)
    end)
  end)

  -- ── song metadata (FretTitle / FretSubtitle / FretTuning / FretOrder) ────────

  describe("song metadata", function()
    it("FretTitle updates the title", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("New Title") end
      vim.cmd("FretTitle")
      vim.ui.input = orig
      assert.equals("New Title", editor._get_state(bufnr).song.title)
    end)

    it("FretTitle clears the title when an empty string is given", function()
      open_test_song("My Song")
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("") end
      vim.cmd("FretTitle")
      vim.ui.input = orig
      assert.is_nil(editor._get_state(bufnr).song.title)
    end)

    it("FretTitle marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("Changed") end
      vim.cmd("FretTitle")
      vim.ui.input = orig
      assert.is_true(editor._get_state(bufnr).dirty)
    end)

    it("FretTitle does nothing when the prompt is cancelled", function()
      open_test_song("My Song")
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb(nil) end
      vim.cmd("FretTitle")
      vim.ui.input = orig
      local st = editor._get_state(bufnr)
      assert.equals("My Song", st.song.title)
      assert.is_false(st.dirty)
    end)

    it("FretSubtitle updates the subtitle", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("Deep Purple") end
      vim.cmd("FretSubtitle")
      vim.ui.input = orig
      assert.equals("Deep Purple", editor._get_state(bufnr).song.subtitle)
    end)

    it("FretSubtitle clears the subtitle when given an empty string", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      st.song.subtitle = "Old Band"
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("") end
      vim.cmd("FretSubtitle")
      vim.ui.input = orig
      assert.is_nil(st.song.subtitle)
    end)

    it("FretSubtitle marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("Band") end
      vim.cmd("FretSubtitle")
      vim.ui.input = orig
      assert.is_true(editor._get_state(bufnr).dirty)
    end)

    it("FretTuning updates the tuning", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("Drop D") end
      vim.cmd("FretTuning")
      vim.ui.input = orig
      assert.equals("Drop D", editor._get_state(bufnr).song.tuning)
    end)

    it("FretTuning clears the tuning when given an empty string", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      st.song.tuning = "Standard"
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("") end
      vim.cmd("FretTuning")
      vim.ui.input = orig
      assert.is_nil(st.song.tuning)
    end)

    it("FretTuning marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("Open G") end
      vim.cmd("FretTuning")
      vim.ui.input = orig
      assert.is_true(editor._get_state(bufnr).dirty)
    end)

    it("FretOrder updates the section order", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("A B A") end
      vim.cmd("FretOrder")
      vim.ui.input = orig
      assert.equals("A B A", editor._get_state(bufnr).song.order)
    end)

    it("FretOrder clears the order when given an empty string", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local st = editor._get_state(bufnr)
      st.song.order = "A B C"
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("") end
      vim.cmd("FretOrder")
      vim.ui.input = orig
      assert.is_nil(st.song.order)
    end)

    it("FretOrder marks the buffer dirty", function()
      open_test_song()
      local bufnr = vim.api.nvim_get_current_buf()
      local orig = vim.ui.input
      vim.ui.input = function(_, cb) cb("A A B") end
      vim.cmd("FretOrder")
      vim.ui.input = orig
      assert.is_true(editor._get_state(bufnr).dirty)
    end)
  end)
end)
