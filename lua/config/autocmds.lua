

--exclude obj files

local disable_obj_csharp_group =
	vim.api.nvim_create_augroup("DisableObjCsharp", { clear = true })

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
	pattern = { "**/obj/**", "/obj/*" },
	callback = function()
		vim.diagnostic.disable(0)
	end,
	group = disable_obj_csharp_group,
})


