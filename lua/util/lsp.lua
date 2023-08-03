local M = {}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

M.capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

M.setup = function()
	vim.diagnostic.config({
		virtual_text = false,
		float = {
			focusable = false,
			style = "minimal",
			border = "rounded",
			source = "always",
			header = "",
			prefix = "",
		},
		signs = true,
		underline = true,
		update_in_insert = true,
		severity_sort = false,
	})

	local Config = require("config")

    ---- sign column
	--local signs = require("util").lsp_signs

	for type, icon in pairs(Config.icons.diagnostics) do
		local hl = "DiagnosticSign" .. type
		vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
	end




local ag = vim.api.nvim_create_augroup
local au = vim.api.nvim_create_autocmd

-- GROUPS:
local disable_obj_csharp_group =
	ag("DisableObjCsharp", { clear = true })

-- AUTO-COMMANDS:
au({ "BufNewFile", "BufRead" }, {
	pattern = { "**/obj/**", "/obj/*" },
	callback = function()
		vim.diagnostic.disable(0)
	end,
	group = disable_obj_csharp_group,
})

end

M.on_attach = function(client, bufnr)

    -- Guard against servers without the signatureHelper capability
        if client.server_capabilities.signatureHelpProvider then

        --Add lsp plugin to allow for overloads
        require('lsp-overloads').setup(client, {
            ui = {
                --Close the UI if the cursor is moved in normal or insert mode
                close_events = { "CursorMoved", "CursorMovedI", "InsertCharPre" },
            },
            keymaps = {
                next_signature = "<A-j>",
                previous_signature = "<A-k>",
                next_parameter = "<A-l>",
                previous_parameter = "<A-h>",
            },
        })
    end


	-- Enable completion triggered by <c-x><c-o>
	vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

	-- Mappings.
	-- See `:help vim.lsp.*` for documentation on any of the below functions
	local bufopts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "<leader>gD", vim.lsp.buf.declaration, bufopts)
	--vim.keymap.set("n", "<leader>gd", "<cmd>Telescope lsp_definitions<cr>", bufopts)
	--vim.keymap.set("n", "<leader>gr", "<cmd>Telescope lsp_references<cr>", bufopts)
	--vim.keymap.set("n", "<leader>gi", "<cmd>Telescope lsp_implementations<cr>", bufopts)
	--vim.keymap.set("n", "<leader>gt", "<cmd>Telescope lsp_type_definitions<cr>", bufopts)
	--vim.keymap.set("n", "<leader>K", vim.lsp.buf.hover, bufopts)
	--vim.keymap.set("n", "<leader>k", vim.lsp.buf.signature_help, bufopts)
	vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, bufopts)
	vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
	vim.keymap.set("n", "<leader>wl", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, bufopts)
	--vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
	--vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
	--vim.keymap.set("n", "<leader>K", vim.lsp.buf.hover, bufopts)
    -- show diagnostics in hover window
	vim.api.nvim_create_autocmd("CursorHold", {
		buffer = bufnr,
		callback = function()
			local opts = {
				focusable = false,
				close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
				border = "rounded",
				source = "always",
				prefix = " ",
				scope = "cursor",
			}
			vim.diagnostic.open_float(nil, opts)
		end,
	})
end

return M

