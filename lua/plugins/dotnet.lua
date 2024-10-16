return {
    {
        'MoaidHathot/dotnet.nvim',
        cmd = "DotnetUI",
        opts = {},
        keys = {
            { "<leader>nn", "<cmd>DotnetUI new_item<cr>",            desc = ".Net New Item (Project, Slan etc.)" },
            { "<leader>nf", "<cmd>DotnetUI file bootstrap<cr>",      desc = ".Net New File" },
            { "<leader>np", "<cmd>DotnetUI project package add<cr>", desc = ".Net Package Add" },
            { "<leader>nf", "<cmd>DotnetUI file bootstrap<cr>",      desc = ".Net File" },
            { "<leader>na", "<cmd>DotnetUI reference add<cr>",       desc = ".Net Reference Add" },
            { "<leader>nr", "<cmd>DotnetUI reference remove<cr>",    desc = ".Net Reference Remove" },
        }
    },
    {
        "GustavEikaas/easy-dotnet.nvim",
        dependencies = { "nvim-lua/plenary.nvim", 'nvim-telescope/telescope.nvim', },
        config = function()
            require("easy-dotnet").setup()
        end
    },
    {
        "seblj/roslyn.nvim",
        ft = "cs",
        opts = {
            -- your configuration comes here; leave empty for default settings
        },
        config = function()
            local lsp_util = require("util.lsp")

            require("roslyn").setup({
                config = {
                    on_attach = lsp_util.on_attach,
                    --on_attach = function(client, bufnr)
                    --    require "lsp_signature".on_attach(signature_setup, bufnr)  -- Note: add in lsp client on-attach
                    --end,

                    settings = {
                        ["csharp|background_analysis"] = {
                            dotnet_compiler_diagnostics_scope = "fullSolution"
                        },
                        ["csharp|inlay_hints"] = {
                            csharp_enable_inlay_hints_for_implicit_object_creation = true,
                            csharp_enable_inlay_hints_for_implicit_variable_types = true,
                            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
                            csharp_enable_inlay_hints_for_types = true,
                            dotnet_enable_inlay_hints_for_indexer_parameters = true,
                            dotnet_enable_inlay_hints_for_literal_parameters = true,
                            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
                            dotnet_enable_inlay_hints_for_other_parameters = true,
                            dotnet_enable_inlay_hints_for_parameters = true,
                            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
                            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
                            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
                        },
                        ["csharp|code_lens"] = {
                            dotnet_enable_references_code_lens = true,
                        },
                    }
                },
                exe = {
                    "dotnet",
                    vim.fs.joinpath(vim.fn.stdpath("data"), "roslyn", "Microsoft.CodeAnalysis.LanguageServer.dll"),
                },
                filewatching = true,
            })


            vim.keymap.set("n", "<leader>p", function()
                local clients = vim.lsp.get_clients()
                for _, value in ipairs(clients) do
                    if value.name == "roslyn" then
                        vim.notify("roslyn client found")
                        value.rpc.request("workspace/diagnostic", { previousResultIds = {} }, function(err, result)
                            if err ~= nil then
                                print(vim.inspect(err))
                            end
                            if result ~= nil then
                                local diags = {}
                                local seen = {}
                                for _, diag in ipairs(result.items) do
                                    local filepath = diag.uri:gsub("file:///", "")
                                    if #diag.items > 0 then
                                        for _, diag_line in ipairs(diag.items) do
                                            if diag_line.severity == 1 then
                                                local hash = diag_line.message ..
                                                    diag_line.range.start.line .. diag_line.range.start.character
                                                if seen[hash] == nil then
                                                    local s = {
                                                        text = diag_line.message,
                                                        lnum = diag_line.range.start.line,
                                                        col = diag_line.range.start.character,
                                                        filename = filepath
                                                    }
                                                    table.insert(diags, s)
                                                    seen[hash] = true
                                                end
                                            end
                                        end
                                    end
                                end
                                vim.fn.setqflist(diags)
                                vim.cmd("copen")
                            end
                        end)
                    end
                end
            end, { noremap = true, silent = true })
        end
    }
}
