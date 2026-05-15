# fret.nvim

```
                  ___
                 /   \
                | o=o |         fret.nvim
                 \___/
                   |
           ========|========
           ========|========    Your playing won't
           ========|========    improve. Your tabs will.
           ========|========
           ========|========
           ========|========
              _____|_____
             /     |     \
            /    ( O )    \
           |               |
           |     ( O )     |
            \             /
             \___________/
```

> A guitar tab editor for Neovim. For the tabs you'll write at midnight,
> forget about, and rediscover six months later wondering who wrote them.

## Features

- 6-string tab grid (e B G D A E) — all the strings, none of the broken ones
- Beat ruler with time signature support (4/4, 3/4, 12/8, whatever you heard on that one album)
- Subdivisions: quarter, 8th, 16th, 32nd — go ahead, write that run you'll never play up to speed
- Multiple named sections (`[Intro]`, `[Verse]`, `[That part I always mess up]`)
- Repeat markers (`|:` / `:|`) so you don't have to copy-paste the same riff four times
- Song title, subtitle and section order (`A A B A C B A` — classic)
- Column + cell highlight so you always know where your cursor went
- Press `?` for a help popup — no more alt-tabbing to the README mid-riff
- Tabs are saved as `.fret` JSON files and can be reopened with `:FretOpen`

## What it looks like

```
Smoke on the Water
Deep Purple
Order: Intro Intro Verse Chorus Verse Chorus Outro

|: [Intro]
4/4  | 1 . 2 . 3 . 4 . |
e    | - - - - - - - - |
B    | - - - - - - - - |
G    | 0 - 3 - 5 - - - |
D    | 0 - 3 - 5 - - - |
A    | - - - - - - - - |
E    | - - - - - - - - |

[Verse]
...
```

Beat numbers go up as high as you need — 12/8 aligns correctly, no shifting.

## Setup (lazy.nvim)

Telescope is required.

```lua
{
  "siatko/fret.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("fret").setup({
      fret_dir = vim.fn.expand("~/Documents/fret"),
      keymaps = {
        new_tab  = "<leader>gt",   -- open new tab editor
        find_tab = "<leader>gf",   -- telescope picker for saved tabs
      },
    })
  end,
}
```


## Workflow

1. `<leader>gt` or `:FretNew` — enter a title (required), then subtitle, time sig, smallest note
2. Write your riff with hjkl + digit keys
3. Add sections with `a`, name them with `r`, add repeats with `[` and `]`
4. Press `Y` to copy to clipboard — the tab is also saved to `fret_dir/<title>.fret`
5. Paste into your markdown/notes/wherever — the code block keeps it monospaced
6. Press `q` to quit (prompts to save if there are unsaved changes)
7. Come back later with `<leader>gf` or `:FretOpen` — telescope picker or fallback select to reopen any saved tab

## Keymaps

Press `?` inside the editor to show this as a popup.

**Navigation**

| Key               | Action                          |
|-------------------|---------------------------------|
| `h` / `l`         | Move left / right (slots)       |
| `j` / `k`         | Move down / up (strings)        |
| `<C-k>` / `<C-j>` | Jump to previous / next section |

**Notes**

| Key     | Action                                                |
|---------|-------------------------------------------------------|
| `0`–`9` | Enter fret number (keep typing for two digits, then `<Enter>`) |
| `x`     | Clear note at cursor                                  |

**Measures**

| Key | Action                 |
|-----|------------------------|
| `m` | Add measure            |
| `M` | Delete current measure |

**Sections**

| Key | Action                          |
|-----|---------------------------------|
| `a` | Add section below current       |
| `D` | Delete current section          |
| `r` | Rename section (prompt)         |
| `[` | Toggle repeat start `\|:`       |
| `]` | Toggle repeat end `:\|`         |

**Song metadata**

| Key | Action              |
|-----|---------------------|
| `T` | Edit title          |
| `U` | Edit subtitle       |
| `G` | Edit tuning         |
| `O` | Edit section order  |

**Other**

| Key | Action                    |
|-----|---------------------------|
| `t` | Change time signature     |
| `s` | Change subdivision        |
| `Y` | Copy tab to clipboard and save to disk |
| `W` | Save tab to disk                       |
| `q` | Quit (prompts if unsaved changes)      |
| `?` | Show keybinding help popup             |

## On open

Five prompts — title is required, the rest are optional (`<Enter>` to skip):

1. **Title** — required; used as the filename when saving (`my-riff.fret`)
2. **Subtitle** — e.g. `Van Halen`
3. **Tuning** — e.g. `Standard`, `Drop D`, `Open G`
4. **Time signature** — pick from presets or type a custom one
5. **Smallest note** — 4th / 8th / 16th / 32nd

Everything can be changed afterwards with `T`, `U`, `G`, `O`, `t`, `s`.

## Section header format

| Has name | Has repeat | Output          |
|----------|------------|-----------------|
| ✓        |            | `[Verse]`       |
| ✓        | start+end  | `\|:  [Chorus]  :\|` |
| ✗        |            | `---`           |
| ✗        | start only | `\|:`           |

## Commands

| Command              | Action                                      |
|----------------------|---------------------------------------------|
| `:FretNew`           | Open a new tab editor                       |
| `:FretOpen [path]`   | Pick a saved tab to reopen (or open a path) |
| `:FretSave`          | Save current tab to disk                    |
| `:FretCopy`          | Copy tab to clipboard and save              |
| `:FretAddMeasure`    | Add a measure                               |
| `:FretTimeSig`       | Change time signature                       |
| `:FretSubdiv`        | Change subdivision                          |
| `:FretAddSection`    | Add section below current                   |
| `:FretDeleteSection` | Delete current section                      |
| `:FretRenameSection` | Rename current section                      |
| `:FretTitle`         | Edit title                                  |
| `:FretSubtitle`      | Edit subtitle                               |
| `:FretTuning`        | Edit tuning                                 |
| `:FretOrder`         | Edit section order                          |

## Files

Tabs are saved as JSON in `fret_dir` (default `~/frets`, configurable):

```lua
require("fret").setup({
  fret_dir = vim.fn.expand("~/Documents/fret"),
})
```

The filename is derived from the title (`My Song.fret`). Saving happens when you press `Y` (copy + save) or `W` (save only). Use `:FretOpen` or `<leader>gf` to browse and reopen saved tabs.

## Global keymaps

These are active everywhere, not just inside the editor:

| Key           | Action                              |
|---------------|-------------------------------------|
| `<leader>gt`  | Open new tab editor (`:FretNew`)    |
| `<leader>gf`  | Telescope picker for saved tabs     |

## Code maintenance

- [ ] `copy_tab` gives no feedback when the tab has no title — `save_with_conflict_check` returns silently, so the clipboard is set but the user sees nothing; restore the "tab copied to clipboard" notify for this case
- [ ] `set_timesig` and `set_subdivision` use `vim.fn.input` (blocking, untestable) while every other prompt uses `vim.ui.input` — makes those two functions inconsistent and impossible to mock in tests
- [ ] `:FretOpen` fallback in `init.lua` duplicates the `glob` logic already in `telescope.lua` — if the path or pattern ever changes it needs updating in two places
- [ ] `M.open` has five levels of nested callbacks — hard to follow and brittle to extend; a flat step-function or recursive approach would be easier to maintain
- [ ] `quit_editor` can leave the user stuck if they try "Save and quit" but have no title and then cancel the rename prompt — the buffer stays open with no clean exit path

## TODO

**Technique markers** (hammer-on `h`, pull-off `p`, slide `/` `\`) are the biggest missing piece compared to real tabs. They are not standalone notes — they are connections *between* two notes. That makes them structurally different from what's here: each slot would need to carry a `connect_out` field (e.g. `"h"`, `"p"`, `"/"`) pointing toward the next slot, and the renderer would have to substitute that character for the space filler it currently puts between the two slots. Until then, you can annotate them by hand after copying with `Y`.

- [ ] Muted/dead notes (`x`) — currently `x` clears a note; it could instead write a muted marker so that the rendered tab shows `x` in the cell rather than `-`
- [ ] BPM / tempo — store a tempo field and display it in the header (e.g. `♩ = 120`) so exported tabs carry timing intent
- [ ] Capo — a single header field (`Capo: 2`) that renders above the first section; fret numbers stay relative to the capo
- [ ] Bar numbers — print a small measure counter above the ruler so readers can navigate long tabs without counting bars by hand
- [ ] Harmonics — natural harmonics `<12>` and artificial harmonics `{12}` use a different cell format; requires a note-type flag alongside the fret number
- [ ] Bends — `7b9` (bend from fret 7 up to the pitch of 9), `br` (bend and release), pre-bends; a decorated note rather than a separate slot, but requires storing a target pitch and bend type alongside the fret number
- [ ] Vibrato (`~`) — simpler than bends since it's just a flag on a note with no second pitch; changes how the cell renders but doesn't affect column width or neighbours
- [ ] Undo/redo — snapshot the song state before every mutation and keep a history stack; removes the risk of accidentally losing work with no recovery
- [ ] Copy/paste measures — yank a measure and paste it elsewhere; useful for repeating riffs without re-entering every note
- [ ] Transpose — shift all frets in the current section or whole song by ±n semitones; handy when a riff sits better one fret up or when adapting to a capo position
