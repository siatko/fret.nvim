# fret.nvim

```
                  ___
                 /   \
                | o=o |         fret.nvim
                 \___/
                   |
           ========|========
           ========|========    Stop scribbling tabs
           ========|========    on napkins. Do it
           ========|========    in Neovim like a pro.
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

> A guitar tab editor for Neovim. Because your bandmates deserve better than a
> blurry photo of a Post-it note.

## Features

- 6-string tab grid (e B G D A E) — all the strings, none of the broken ones
- Beat ruler with time signature support (4/4, 3/4, 12/8, whatever weird thing you're playing)
- Subdivisions: quarter, 8th, 16th, 32nd notes — go ahead, write that sweep picking run
- Multiple named sections (`[Intro]`, `[Verse]`, `[That part you always mess up]`)
- Repeat markers (`|:` / `:|`) so you don't have to write the chorus four times
- Song title, subtitle and section order (`A A B A C B A` — classic)
- Column + cell highlight so you always know where the cursor is
- Press `?` for a help popup — no more tab-switching to the README

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

```lua
{
  "siatko/fret.nvim",
  config = function()
    require("fret").setup({
      subdivision = 4,             -- 1=quarter, 2=8th, 4=16th, 8=32nd
      time_sig    = { num=4, den=4 },
      keymaps = {
        new_tab = "<leader>gt",    -- g for guitar, t for tab, genius
      },
    })
  end,
}
```

## Workflow

1. `<leader>gt` or `:FretNew` — answer four quick prompts (title, subtitle, time sig, smallest note)
2. Write your riff with hjkl + digit keys
3. Add sections with `a`, name them with `r`, add repeats with `[` and `]`
4. Press `Y` to yank the whole thing to the clipboard
5. Paste into your markdown/txt/wherever — done

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
| `O` | Edit section order  |

**Other**

| Key | Action                    |
|-----|---------------------------|
| `t` | Change time signature     |
| `s` | Change subdivision        |
| `Y` | Copy entire tab to clipboard |
| `?` | Show keybinding help popup |

## On open

Four prompts, all optional (just hit `<Enter>` to skip any of them):

1. **Title** — e.g. `Eruption`
2. **Subtitle** — e.g. `Van Halen`
3. **Time signature** — pick from presets or type a custom one
4. **Smallest note** — 4th / 8th / 16th / 32nd

Everything can be changed afterwards with `T`, `U`, `O`, `t`, `s`.

## Section header format

| Has name | Has repeat | Output          |
|----------|------------|-----------------|
| ✓        |            | `[Verse]`       |
| ✓        | start+end  | `\|:  [Chorus]  :\|` |
| ✗        |            | `---`           |
| ✗        | start only | `\|:`           |

## Commands

| Command              | Action                     |
|----------------------|----------------------------|
| `:FretNew`           | Open a new tab editor      |
| `:FretAddMeasure`    | Add a measure              |
| `:FretTimeSig`       | Change time signature      |
| `:FretSubdiv`        | Change subdivision         |
| `:FretCopy`          | Copy tab to clipboard      |
| `:FretAddSection`    | Add section below current  |
| `:FretDeleteSection` | Delete current section     |
| `:FretRenameSection` | Rename current section     |
| `:FretTitle`         | Edit title                 |
| `:FretSubtitle`      | Edit subtitle              |
| `:FretOrder`         | Edit section order         |
