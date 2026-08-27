-- Remap space as leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- NOTE: this is a no-op. It sets a global variable named "nofsync", not the
-- real 'fsync' option -- that would be vim.o.fsync = false (Lua doesn't
-- translate ":set nofsync" into vim.g.nofsync the way vimscript did). The
-- 'fsync' option is currently on (default) in this build either way. Left
-- as-is pending a decision on whether disabling fsync (faster writes, less
-- durable against a crash/power-loss right after :w) is actually wanted --
-- see plugin-audit-native-replacements.md.
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

set.foldenable = false
