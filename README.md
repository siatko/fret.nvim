# fret.nvim

```
                  ___
                 /   \
                | o=o |         fret.nvim
                 \___/
                   |
           ========|========
           ========|========    Interactive guitar
           ========|========    tab editor for
           ========|========    Neovim.
           ========|========
           ========|========
              _____|_____
             /     |     \
            /    ( O )    \
           |               |
           |    ( O )      |
            \             /
             \___________/
```

Interactive guitar tab editor for Neovim.

## Features

- 6-string tab grid (e B G D A E)
- Beat ruler with time signature display (4/4, 3/4, …)
- Configurable subdivisions: quarter, 8th, or 16th note slots
- Multiple named sections with optional repeat markers (`|:` / `:|`)
- Song title, subtitle and section order field
- Navigate with hjkl; type fret numbers directly
- Press `?` for a keybinding reference popup at any time

## Display

```
My Song
Guitar Tab
Order: A A B C

|: [A]
4/4 | 1 . . . 2 . . . 3 . . . 4 . . . |
e   | - - - - - - - - - - - - - - - - |
B   | - - - - - - - - - - - - - - - - |
G   | - - - - - - - - - - - - - - - - |
D   | - - - - - - - - - - - - - - - - |
A   | - - - - - - - - - - - - - - - - |
E   | - - - - - - - - - - - - - - - - |

[B]  :|
4/4 | 1 . . . 2 . . . 3 . . . 4 . . . |
...
```

Dots (`.`) are subdivision ticks between beats.

## Setup (lazy.nvim)

```lua
{
  "siatko/fret.nvim",
  config = function()
    require("fret").setup({
      subdivision = 4,             -- 1=quarter, 2=8th, 4=16th
      time_sig    = { num=4, den=4 },
      keymaps = {
        new_tab = "<leader>gt",
      },
    })
  end,
}
```

## Keymaps (inside the tab editor)

Press `?` to show this reference inside Neovim.

**Navigation**

| Key              | Action                        |
|------------------|-------------------------------|
| `h` / `l`        | Move left / right (slots)     |
| `j` / `k`        | Move down / up (strings)      |
| `<C-k>` / `<C-j>`| Previous / next section       |

**Notes**

| Key     | Action                        |
|---------|-------------------------------|
| `0`–`9` | Enter fret number             |
| `x`     | Clear note at cursor          |

**Measures**

| Key | Action                        |
|-----|-------------------------------|
| `m` | Add measure                   |
| `M` | Delete current measure        |

**Sections**

| Key   | Action                              |
|-------|-------------------------------------|
| `a`   | Add new section below current       |
| `D`   | Delete current section              |
| `r`   | Rename current section              |
| `[`   | Toggle repeat start (`\|:`)         |
| `]`   | Toggle repeat end (`:\|`)           |

**Song metadata**

| Key | Action                        |
|-----|-------------------------------|
| `T` | Edit title                    |
| `U` | Edit subtitle                 |
| `O` | Edit section order            |

**Other**

| Key | Action                        |
|-----|-------------------------------|
| `t` | Change time signature         |
| `s` | Change subdivision            |
| `Y` | Copy tab to clipboard         |
| `?` | Show keybinding help popup    |

**Entering a fret:** type the first digit; for two-digit frets (e.g. 12) keep typing, then press `<Enter>` to confirm.

**Workflow:** build the tab section by section → press `Y` to copy everything → paste into a markdown file or anywhere else.

## On open

`:FretNew` (or `<leader>gt`) walks you through four prompts:

1. **Title** — optional, press `<Enter>` to skip
2. **Subtitle** — optional, press `<Enter>` to skip
3. **Time signature** — picker with common presets + Custom option
4. **Smallest note** — 4th / 8th / 16th / 32nd

All four fields are editable at any time with `T`, `U`, `O`, `t`, `s`.

## Commands

| Command             | Action                          |
|---------------------|---------------------------------|
| `:FretNew`          | Open a new tab editor           |
| `:FretAddMeasure`   | Add a measure                   |
| `:FretTimeSig`      | Change time signature           |
| `:FretSubdiv`       | Change subdivision              |
| `:FretCopy`         | Copy tab to clipboard           |
| `:FretAddSection`   | Add section below current       |
| `:FretDeleteSection`| Delete current section          |
| `:FretRenameSection`| Rename current section          |
| `:FretTitle`        | Edit title                      |
| `:FretSubtitle`     | Edit subtitle                   |
| `:FretOrder`        | Edit section order              |
