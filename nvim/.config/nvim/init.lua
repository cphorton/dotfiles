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


vim.lsp.enable({
  -- lua
  "lua",
  -- csharp
  "roslyn"
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
