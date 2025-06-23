local map = vim.api.nvim_set_keymap
local opts = {noremap = true, silent = true}

local get_opts = function(desc_text)
    return {noremap = true, silent = true, desc = desc_text}
end

--Stamp
map("n", "S", [["_diwP]], get_opts("(S)tamp"))

--home moves to the beginning 
map('i', '<HOME>', '<esc>I', get_opts("Home to first word"))

map("n", "<C-d>", "<C-d>zz", opts) --zz recentres after the page down
map("n", "<C-u>", "<C-u>zz", opts) --zz recentres after the page up
map("n", "n", "nzzzv", opts) --zz recentres after the page up
map("n", "N", "Nzzzv", opts) --zz recentres after the page up

-- Better window navigation
map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)

-- Resize with arrows
map("n", "<C-Up>", ":resize -2<CR>", opts)
map("n", "<C-Down>", ":resize +2<CR>", opts)
map("n", "<C-Left>", ":vertical resize -2<CR>", opts)
map("n", "<C-Right>", ":vertical resize +2<CR>", opts)


--code
map("n", "<leader>cr", ":lua vim.lsp.buf.rename()<CR>", get_opts("(r)ename"))
map("n", "<leader>ca", ":lua require('tiny-code-action').code_action()<CR>", get_opts("(a)ctions"))
--map("n", "<leader>ca", ":lua vim.lsp.buf.code_action()<CR>", get_opts("(a)ctions"))
map("n", "<leader>ch", ":lua vim.lsp.buf.hover()<CR>", get_opts("(h)over"))
map("n", "<leader>cf", ":lua vim.lsp.buf.format()<CR>", get_opts("(f)ormat"))
map("n", "<leader>cd", ":lua vim.diagnostic.open_float()<CR>", get_opts("(d)iagnostics"))
map("n", "<leader>c<Down>", ":lua vim.diagnostic.goto_next()<CR>", get_opts("Next Diagnostic"))
map("n", "<leader>c<Up>", ":lua vim.diagnostic.goto_prev()<CR>", get_opts("Previous Diagnostic"))



map("n", "gd", ":lua vim.lsp.buf.definition()<CR>", get_opts("Definitions"))
