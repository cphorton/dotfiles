return {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
        require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/lua/snippets/" })
        vim.keymap.set("n", "<leader><leader>s", "<cmd>source ~/.config/nvim/lua/plugins/luasnip.lua<CR>")
    end,
    keys = {
        {
            "<tab>",
            function()
                return require("luasnip").jumpable(1) and "<Plug>luasnip-jump-next" or "<tab>"
            end,
            expr = true,
            silent = true,
            mode = "i",
        },
        { "<tab>",   function() require("luasnip").jump(1) end,  mode = "s" },
        { "<s-tab>", function() require("luasnip").jump(-1) end, mode = { "i", "s" } },
        {
            "<c-e>",

            function()
                if (require("luasnip").choice_active()) then
                    require("luasnip").change_choice(1)
                end
            end,
            mode = { "i", "s" }
        }
    },
}
