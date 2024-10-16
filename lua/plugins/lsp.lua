return {
    "neovim/nvim-lspconfig",
    event = "BufReadPre",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "williamboman/mason-lspconfig.nvim",
        "Hoffs/omnisharp-extended-lsp.nvim",
        "Issafalcon/lsp-overloads.nvim"
    },
    config = function()
        local icons = require("config.icons").icons
        
        local lspconfig = require("lspconfig")

        local capabilities = require('cmp_nvim_lsp').default_capabilities()

        vim.diagnostic.config({
            --Set virtual text to only show foor warnings and above
            virtual_text = {
                update_in_insert = false,
                severity = {
                    min = vim.diagnostic.severity.WARN
                }
            },
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
            signs = {
                text = {
                    [1] = icons.diagnostics.Error,
                    [2] = icons.diagnostics.Warn,
                    [3] = icons.diagnostics.Hint,
                    [4] = icons.diagnostics.Info
                },
            },
            underline = true,
            update_in_insert = true,
            severity_sort = false,
        })
    end
}
