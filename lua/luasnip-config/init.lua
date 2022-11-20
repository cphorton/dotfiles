local ls = require("luasnip")



--require("luasnip-config.csharp-snippets")


ls.setup({
    history = true,
	-- Update more often, :h events for more info.
	update_events = "TextChanged,TextChangedI",
    enable_autosnippets = true
})


--<c-k>
--Allow you to expand the current item or jump to the next item

vim.keymap.set({"i","s"}, "<c-k>", function()
    if ls.expand_or_jumpable() then
        ls.expand_or_jump()
    end
end, {silent = true})

vim.keymap.set({"i","s"}, "<c-j>", function()
    if ls.jumpable(-1) then
        ls.jump(-1)
    end
end, {silent = true})

vim.keymap.set("i", "<c-l>", function()
    if ls.choice_active() then
        ls.choice_active(1)
    end
end)










vim.keymap.set("n", "<leader><leader>s","<cmd>source ~/.config/nvim/lua/luasnip-config/init.lua<CR>")

require("luasnip.loaders.from_lua").load({paths = "~/.config/nvim/snippets/"})

--require("luasnip-config.csharp-snippets")
--require("luasnip.loaders.from_snipmate").load()

