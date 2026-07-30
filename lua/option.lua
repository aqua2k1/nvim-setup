vim.loader.enable()

vim.g.mapleader = " "      -- <space>
vim.g.maplocalleader = " " -- <space>

-- Use an indentation of 4 spaces.
vim.o.sw = 4
vim.o.ts = 4
vim.o.et = true

-- Show line numbers.
vim.wo.number = true
vim.opt.relativenumber = true

-- Enable mouse mode.
vim.o.mouse = 'a'

-- Wrap long lines at words.
vim.o.linebreak = true

-- Sync clipboard between the OS and Neovim.
-- WSL: pin xclip so provider detection does not walk the huge Windows PATH.
local is_wsl = vim.fn.has("wsl") == 1
  or (vim.uv.os_uname().release or ""):lower():find("microsoft", 1, true) ~= nil
if is_wsl then
  vim.g.clipboard = {
    name = "xclip",
    copy = {
      ["+"] = { "xclip", "-quiet", "-i", "-selection", "clipboard" },
      ["*"] = { "xclip", "-quiet", "-i", "-selection", "primary" },
    },
    paste = {
      ["+"] = { "xclip", "-o", "-selection", "clipboard" },
      ["*"] = { "xclip", "-o", "-selection", "primary" },
    },
    cache_enabled = 1,
  }
  vim.o.clipboard = "unnamedplus"
else
  vim.schedule(function() vim.o.clipboard = "unnamedplus" end)
end

-- Save undo history.
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or the search has capitals.
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default.
vim.wo.signcolumn = 'yes'

-- Update times and timeouts.
vim.o.updatetime = 300
vim.o.timeoutlen = 600
vim.o.ttimeoutlen = 10

-- Completion.
vim.opt.wildignore:append { '.DS_Store' }
vim.o.completeopt = 'menuone,noselect,noinsert'
vim.o.pumheight = 15

-- Diff mode settings.
-- Setting the context to a very large number disables folding.
vim.opt.diffopt:append 'vertical,context:99'

vim.opt.shortmess:append {
    I = true,     -- Disable the vim intro.
    w = true,
    s = true,
}

-- Use ripgrep for grepping.
vim.o.grepprg = 'rg --vimgrep'
vim.o.grepformat = '%f:%l:%c:%m'

-- only set clipboard if not in ssh, to make sure the OSC 52
vim.opt.confirm = true
vim.opt.cursorline = true
vim.opt.fillchars = {
    foldopen = "",
    foldclose = "",
    fold = " ",
    foldsep = " ",
    diff = "╱",
    eob = " ",
}

-- load .nvim.lua/.nvimrc
vim.opt.exrc = true

vim.opt.splitbelow = true
vim.opt.splitkeep = "screen"
vim.opt.splitright = true

-- Disable health checks for these providers.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

vim.opt.winborder = 'rounded'
