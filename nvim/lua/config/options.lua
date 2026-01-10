-- Neovim options
-- Ported from .vimrc

local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.showmode = false  -- shown in statusline
opt.laststatus = 3    -- global statusline
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Editing
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.wrap = false
opt.breakindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Files
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undodir = vim.fn.stdpath("state") .. "/undo"

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumheight = 10

-- Misc
opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.timeoutlen = 300
opt.updatetime = 250
opt.hidden = true
opt.shortmess:append("c")

-- Folding (using treesitter)
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldenable = false
opt.foldlevel = 99

-- Disable netrw (using oil.nvim instead)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
