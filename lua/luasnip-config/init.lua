local ls = require("luasnip")

local types = require("luasnip.util.types")


--require("luasnip-config.csharp-snippets")


ls.setup({
    history = true,
	-- Update more often, :h events for more info.
	update_events = "TextChanged,TextChangedI",
    enable_autosnippets = true,
    ext_opts = {
		[types.choiceNode] = {
			active = {
				virt_text = { { "●", "CmpItemKindUnit" } },

			},
		},
    },
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
        ls.change_choice(1)
    end
end,
{desc = "Snippet Choices"})


-- local luaSnipSource
--
-- if vim.fn.has('win32') == 1 then
--   luaSnipSource = 'C:\\Program Files\\Omnisharp\\omnisharp.dll', "--languageserver", "--hostpid", tostring(pid)}
-- elseif vim.fn.has('linux') == 1 then
--   omniSharpCommand = { '/usr/bin/omnisharp', "--languageserver", "--hostpid", tostring(pid)}
-- end

vim.keymap.set("n", "<leader><leader>s","<cmd>source ~/.config/nvim/lua/luasnip-config/init.lua<CR>")

require("luasnip.loaders.from_lua").load({paths = "~/.config/nvim/snippets/"})

--require("luasnip-config.csharp-snippets")
--require("luasnip.loaders.from_snipmate").load()

