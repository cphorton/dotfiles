return {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
        require("luasnip.loaders.from_lua").load({paths = "~/.config/nvim/lua/snippets/"})
        vim.keymap.set("n", "<leader><leader>s","<cmd>source ~/.config/nvim/lua/plugins/luasnip.lua<CR>")
    end
}
