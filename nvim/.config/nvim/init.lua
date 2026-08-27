require("config.options")
require("config.lazy")


vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    callback = function()
        --require("config.autocmds")
        require("config.keymaps")

        require("snacks.dashboard")

    end,
})


-- Only "lua" needs an explicit vim.lsp.enable() call here. C# LSP settings
-- live in lsp/easy_dotnet.lua but are picked up differently: Neovim
-- auto-populates vim.lsp.config[name] from any lsp/<name>.lua file on the
-- runtimepath regardless of vim.lsp.enable, and easy-dotnet.nvim's own
-- roslyn/lsp.lua reads vim.lsp.config[constants.lsp_client_name] directly
-- (lsp_client_name == "easy_dotnet", matching the filename) when it sets up
-- the Roslyn client itself -- so it's live without ever being "enabled" here.
vim.lsp.enable({
  -- lua
  "lua",
 })

local icons = require("config.icons").icons
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
