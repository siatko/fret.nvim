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
- Navigate with hjkl; type fret numbers directly
- Add/remove measures on the fly

## Display

```
4/4 | 1 . . . 2 . . . 3 . . . 4 . . . | 1 . . . 2 . . . ...
e   | - - - - - - - - - - - - - - - - | - - - - - - - - ...
B   | - - - - - - - - - - - - - - - - | - - - - - - - - ...
G   | - - - - - - - - - - - - - - - - | - - - - - - - - ...
D   | - - - - - - - - - - - - - - - - | - - - - - - - - ...
A   | - - - - - - - - - - - - - - - - | - - - - - - - - ...
E   | - - - - - - - - - - - - - - - - | - - - - - - - - ...
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
        new_tab = "<leader>fg",
      },
    })
  end,
}
```

## Keymaps (inside the tab editor)

**Notes**

| Key       | Action                       |
|-----------|------------------------------|
| `h` / `l` | Move left / right (slots)    |
| `j` / `k` | Move down / up (strings)     |
| `0`–`9`   | Enter fret number            |
| `x`       | Clear note at cursor         |
| `m`       | Append a new measure         |
| `M`       | Delete current measure       |
| `t`       | Change time signature        |
| `s`       | Change subdivision           |
| `Y`       | Copy whole tab to clipboard  |

**Sections**

| Key  | Action                              |
|------|-------------------------------------|
| `a`  | Add new section below current       |
| `D`  | Delete current section              |
| `r`  | Rename current section              |
| `[`  | Toggle repeat start (`\|:`) on section |
| `]`  | Toggle repeat end (`:\|`) on section   |
| `{`  | Jump to previous section            |
| `}`  | Jump to next section                |

**Entering a fret:** type the first digit; for two-digit frets (e.g. 12) keep typing, then press `<Enter>` to confirm.

**Workflow:** build the tab section by section, press `Y` to copy everything, paste into a markdown file.

## Section output format

```
|: [Verse]
4/4 | 1 . . . 2 . . . |
e   | - - - - - - - - |
...

[Chorus]  :|
4/4 | 1 . . . 2 . . . |
e   | - - - - - - - - |
```

## Commands

- `:FretNew` — open a new tab editor (prompts for time sig and smallest note)
- Inside the buffer: `:FretAddMeasure`, `:FretTimeSig`, `:FretSubdiv`, `:FretCopy`, `:FretAddSection`, `:FretDeleteSection`, `:FretRenameSection`
