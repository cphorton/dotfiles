local ls = require("luasnip")

ls.setup({
    history = true,
	-- Update more often, :h events for more info.
	update_events = "TextChanged,TextChangedI",
    enable_autosnippets = true
})




require("luasnip.loaders.from_snipmate").load()

