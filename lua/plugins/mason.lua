
return {
    {
	"williamboman/mason.nvim",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    build = ":MasonUpdate",
    lazy = false,
	opts = {
		pip = {
			upgrade_pip = true,
		},
		ui = {
			border = "rounded",
			icons = {
				package_installed = "✓",
				package_pending = "➜",
				package_uninstalled = "✗",
			},
		},
	},
    config = function(_,opts)
        require("mason").setup(opts)
    end,
    },
    {
"neovim/nvim-lspconfig",
    event = "BufReadPre",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "williamboman/mason-lspconfig.nvim",
        "Hoffs/omnisharp-extended-lsp.nvim",
        "Issafalcon/lsp-overloads.nvim"
    },
    config = function(_, opts)
        local util = require("util")
        local mason_lspconfig = require("mason-lspconfig")
        local lspconfig = require("lspconfig")
        local lsp_utils = require("util.lsp")
        lsp_utils.setup()

        mason_lspconfig.setup({
            ensure_installed = util.lsp_servers,
        })

        mason_lspconfig.setup_handlers({
            function(server_name)
                lspconfig[server_name].setup({
                    on_attach = lsp_utils.on_attach,
                    capabilities = lsp_utils.capabilities,
                })
            end,
            ["omnisharp"] = function()
                lspconfig.omnisharp.setup {
                    on_attach = lsp_utils.on_attach,
                    capabilities = lsp_utils.capabilities,
                    solution_first = true,
                    automatic_dap_configuration = true,
                    highlight = {
                        enabled = true,
                        fixSemanticTokens = true,
                        --groups = {
                        --    OmniSharpEnumName              = { link = '@enum' },
                        --    OmniSharpInterfaceName         = { link = '@interface' },
                        --    OmniSharpStructName            = { link = '@struct' },
                        --    OmniSharpTypeParameterName     = { link = '@typeParameter' },
                            --OmniSharpPreprocessorKeyword   = { fg = vim.fn['ayu#get_color']('extended_fg_idle') },
                        --    OmniSharpPropertyName          = { link = '@property' },
                        --    OmniSharpFieldName             = { link = '@field' },
                        --    OmniSharpParameterName         = { link = '@parameter' },
                            --OmniSharpVerbatimStringLiteral = { fg = vim.fn['ayu#get_color']('syntax_regexp') },
                            --OmniSharpLocalName             = { fg = vim.fn['ayu#get_color']('editor_fg') }
                        --},
                    },
                        handlers = {
                            ['textDocument/definition'] = require('omnisharp_extended').handler
                        }
                }
            end

        })
    end,

    }



}
