# nvim-setup

Personal Neovim configuration focused on viewing code and files and editing prompts.

## Prerequisites

- **Neovim >= 0.10** (uses `vim.loader`, `snacks.nvim`, `blink.cmp`)
- **git** — plugin management
- **ripgrep** (`rg`) — grep provider
- **cargo** (Rust) — `blink.cmp` build
- xclip (WSL only) — clipboard sync

### Optional

- [llama.cpp](https://github.com/ggerganov/llama.cpp) + `llama-server` — built-in AI translation (`<leader>at` / `<leader>aT`)
- [macism](https://github.com/laishulu/macism) — auto IME switch on macOS

## Install

```bash
git clone git@github.com:aqua2k1/nvim-setup.git ~/.config/nvim
```

Open Neovim — `lazy.nvim` bootstraps itself and installs all plugins on first run.
Treesitter core parsers install automatically.

## Structure

```
~/.config/nvim/
├── init.lua                  # Entry point
├── lazy-lock.json            # Plugin version lock
├── lua/
│   ├── option.lua            # Editor options
│   ├── keymap.lua            # Global keymaps
│   ├── autocmd.lua           # Autocommands
│   ├── plugin.lua            # lazy.nvim bootstrap
│   ├── statusline.lua        # Statusline
│   ├── tabline.lua           # Tabline
│   ├── plugins/              # Plugin specs (lazy.nvim)
│   │   ├── cmp.lua           # blink.cmp
│   │   ├── file.lua          # oil.nvim
│   │   ├── git.lua           # codediff.nvim
│   │   ├── markdown.lua      # markview.nvim
│   │   ├── mini.lua          # mini.surround / mini.pairs
│   │   ├── pick.lua          # fzf-lua
│   │   ├── snacks.lua        # snacks.nvim
│   │   ├── term.lua          # toggleterm.nvim
│   │   ├── translate.lua     # Custom translation plugin
│   │   ├── treesitter.lua    # nvim-treesitter
│   │   └── which_key.lua     # which-key.nvim
│   ├── user-plugins/
│   │   └── translate/        # AI translation plugin
│   └── utils/                # Shared color palette
├── colors/                   # Colorschemes
├── snippets/                 # Code snippets
└── scripts/
    └── llama-translate.sh    # Translation model setup
```

## Keymaps

Leader key: `<Space>`

### File & Search

| Key | Description |
|-----|-------------|
| `<leader>ff` | Find files (project root) |
| `<leader>fF` | Find files (custom directory) |
| `<leader>fg` | Find git files |
| `<leader>fo` | Recent files |
| `<leader>fw` | Live grep (project root) |
| `<leader>fW` | Live grep (custom directory) |
| `<leader>fh` | Help tags |
| `<leader>fk` | Keymaps |
| `<leader>fc` | Commands |

### Git (codediff)

Entry keymaps:

| Key | Description |
|-----|-------------|
| `<leader>gd` | CodeDiff: file vs HEAD |
| `<leader>gD` | CodeDiff: file vs HEAD~1 |
| `<leader>ge` | CodeDiff: changed files |
| `<leader>gh` | CodeDiff: commit history |

Inside CodeDiff view:

| Key | Description |
|-----|-------------|
| `q` | Quit |
| `t` | Toggle side-by-side / inline |
| `gc` | Toggle compact (fold unchanged) |
| `]c` / `[c` | Next / prev hunk |
| `]f` / `[f` | Next / prev file |
| `-` | Stage / unstage current file |
| `S` / `U` | Stage / unstage all |
| `X` | Restore (discard changes) |
| `<leader>hs` / `hu` / `hr` | Hunk stage / unstage / discard |
| `do` / `dp` | Diff get / put |
| `<leader>go` / `gt` | Accept ours / theirs (conflict) |
| `]x` / `[x` | Next / prev conflict |

### Buffers & Windows

| Key | Description |
|-----|-------------|
| `<leader>,` | Switch buffer (fzf) |
| `[b` / `]b` | Prev / next buffer |
| `<leader>bd` | Delete buffer |
| `<leader>bv` | Vertical split |
| `<leader>bs` | Horizontal split |
| `<leader>bc` | New empty buffer |
| `<leader>e` | Oil file explorer |
| `<C-Up/Down>` | Resize height |
| `<C-Left/Right>` | Resize width |

### Terminal

| Key | Description |
|-----|-------------|
| `<leader>tv` | Terminal (vertical split) |
| `<leader>ts` | Terminal (horizontal split) |
| `<leader>tf` | Terminal (float) |
| `<leader>tt` | Terminal (tab) |
| `<leader>tc` | Run command in terminal |

In terminal mode: `<Esc><Esc>` to enter normal mode, `<C-w>` + hjkl to navigate.

### Translation (requires llama.cpp)

| Key | Description |
|-----|-------------|
| `<leader>at` | Translate to side panel |
| `<leader>aT` | Translate & replace in-place |

Visual mode: translate selection only. Normal mode: translate entire buffer.

See [Translation](#translation) for setup.

### Misc

| Key | Description |
|-----|-------------|
| `<C-s>` | Save file |
| `gc[oO]` | Comment below / above |
| `<leader>q` | Toggle quickfix |
| `[q` / `]q` | Prev / next quickfix |
| `<leader>?` | Buffer-local keymaps (which-key) |
| `<F10>` | Lazy dashboard |

### Motion

| Key | Description |
|-----|-------------|
| `j` / `k` | gj / gk (visual line) |
| `gh` / `gl` | Line start / end |
| `gm` | Match bracket (%) |

## Translation

Built-in AI translation using local [llama.cpp](https://github.com/ggerganov/llama.cpp) with the Hy-MT2 model.

### Setup

```bash
# One-time setup
./scripts/llama-translate.sh
```

This clones llama.cpp, builds it, and downloads the translation model (`Hy-MT2-1.8B-Q4_K_M.gguf`).

### Usage

- `<leader>at` — translate buffer/selection to a side-panel (scratch buffer)
- `<leader>aT` — translate and replace buffer/selection in-place

Prompts for target language (en/zh). The model idle-unloads after 10 minutes.

## Platform Notes

### WSL

Clipboard is automatically routed through `xclip`. Install it:

```bash
sudo apt install xclip
```

### macOS

Input method auto-switching: switches to ABC layout on leaving insert mode, restores previous layout on entering. Requires [macism](https://github.com/laishulu/macism):

```bash
brew install macism
```

### SSH

Uses OSC 52 for clipboard when in SSH sessions — no extra setup needed.

## Customization

- `.nvim.lua` or `.nvimrc` in any project directory is auto-loaded (`exrc = true`)
- Add new lazy plugin specs under `lua/plugins/` — imported via `{ import = "plugins" }`
