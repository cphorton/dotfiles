local map = vim.api.nvim_set_keymap
local opts = {noremap = true, silent = true}

local get_opts = function(desc_text)
    return {noremap = true, silent = true, desc = desc_text}
end

--Stamp
map("n", "S", [["_diwP]], opts)



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

--Code
map("n", "gd", ":lua require('omnisharp_extended').lsp_definitions()<CR>", get_opts("(G)o to (d)efinition"))
map("n", "<leader>cr", ":lua vim.lsp.buf.rename()<CR>", get_opts("(r)ename"))
map("n", "<leader>ca", ":lua vim.lsp.buf.code_action()<CR>", get_opts("(a)ctions"))
map("n", "<leader>ch", ":lua vim.lsp.buf.hover()<CR>", get_opts("(h)over"))
map("n", "<leader>cf", ":lua vim.lsp.buf.format()<CR>", get_opts("(f)ormat"))
map("n", "<leader>cd", ":lua vim.diagnostic.open_float()<CR>", get_opts("(d)iagnostics"))
map("n", "K", ":lua vim.lsp.buf.hover()<CR>", get_opts("Hover"))
map("n", "gK", ":lua vim.lsp.buf.signature_help()<CR>", get_opts("Signature Help"))
map("i", "<c-k>", ":lua vim.lsp.buf.signature_help()<CR>", get_opts("Signature Help"))
