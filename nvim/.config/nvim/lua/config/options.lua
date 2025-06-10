-- Remap space as leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.nofsync = true


local set = vim.opt

set.number = true
set.expandtab = true
set.smarttab = true
set.shiftwidth = 4
set.tabstop = 4
set.signcolumn = "yes" --keep a set width for the sign column
set.scrolloff = 5
set.termguicolors = true

set.ignorecase = true
set.smartcase = true

--set.autoindent = true
--set.smartindent = true
set.cindent = true


set.relativenumber = true
set.cursorline = true

--set.clipboard = 'unnamedplus'
set.colorcolumn = '120'
