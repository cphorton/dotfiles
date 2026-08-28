-- Global editor keymaps. Plugin-specific keymaps live next to their plugin
-- spec instead (e.g. lua/plugins/dap.lua's `keys = {}`) so lazy.nvim can
-- lazy-load on first use -- see lua/plugins/dap.lua for that convention.
local opts = { silent = true }

local function desc(text)
    return { silent = true, desc = text }
end

--Stamp
vim.keymap.set("n", "S", [["_diwP]], desc("(S)tamp"))

--home moves to the beginning
vim.keymap.set("i", "<Home>", "<Esc>I", desc("Home to first word"))

vim.keymap.set("n", "<C-d>", "<C-d>zz", opts) --zz recentres after the page down
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts) --zz recentres after the page up
vim.keymap.set("n", "n", "nzzzv", opts) --zz recentres after search next
vim.keymap.set("n", "N", "Nzzzv", opts) --zz recentres after search prev

-- Better window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", opts)
vim.keymap.set("n", "<C-j>", "<C-w>j", opts)
vim.keymap.set("n", "<C-k>", "<C-w>k", opts)
vim.keymap.set("n", "<C-l>", "<C-w>l", opts)

-- Resize with arrows
vim.keymap.set("n", "<C-Up>", "<Cmd>resize -2<CR>", opts)
vim.keymap.set("n", "<C-Down>", "<Cmd>resize +2<CR>", opts)
vim.keymap.set("n", "<C-Left>", "<Cmd>vertical resize -2<CR>", opts)
vim.keymap.set("n", "<C-Right>", "<Cmd>vertical resize +2<CR>", opts)

--code
vim.keymap.set("n", "<leader>cr", function() vim.lsp.buf.rename() end, desc("(r)ename"))
vim.keymap.set("n", "<leader>ca", function() require("tiny-code-action").code_action() end, desc("(a)ctions"))
vim.keymap.set("n", "<leader>ch", function() vim.lsp.buf.hover() end, desc("(h)over"))
vim.keymap.set("n", "<leader>cf", function() vim.lsp.buf.format() end, desc("(f)ormat"))
vim.keymap.set("n", "<leader>cd", function() vim.diagnostic.open_float() end, desc("(d)iagnostics"))
vim.keymap.set("n", "<leader>cl", function() vim.lsp.codelens.run() end, desc("Run Code(l)ens"))
vim.keymap.set("n", "<A-Down>", function() vim.diagnostic.goto_next() end, desc("Next Diagnostic"))
vim.keymap.set("n", "<A-Up>", function() vim.diagnostic.goto_prev() end, desc("Previous Diagnostic"))
