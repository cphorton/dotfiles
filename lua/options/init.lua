local set = vim.opt


set.expandtab = true
set.smarttab = true
set.shiftwidth = 4
set.tabstop = 4
set.softtabstop = 4
set.smartindent = true
set.copyindent = true
set.preserveindent = true

set.wrap = false

set.scrolloff = 5
set.termguicolors = true

set.ignorecase = true
set.smartcase = true


set.relativenumber = true
set.nu = true
set.cursorline = true
set.colorcolumn = '140'

-- set.signcolumn = 'number'

vim.notify = require('notify')
