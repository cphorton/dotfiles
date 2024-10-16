local M = {}

M.setup = function()
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
                ['ERROR'] = icons.diagnostics.Error,
                ['WARN'] = icons.diagnostics.Warn,
                ['HINT'] = icons.diagnostics.Hint,
                ['INFO'] = icons.diagnostics.Info
            },
        },
        underline = true,
        update_in_insert = true,
        severity_sort = false,
    })
end

M.on_attach = function(client, bufnr)

    -- Guard against servers without the signatureHelper capability
    if client.server_capabilities.signatureHelpProvider then
        --Add lsp plugin to allow for overloads
        require('lsp-overloads').setup(client, {
            ui = {
                max_width = 80,
                --Close the UI if the cursor is moved in normal or insert mode
                close_events = { "CursorMoved", "CursorMovedI", "InsertCharPre" },

                floating_window_above_current_line = true
            },
            keymaps = {
                next_signature = "<A-j>",
                previous_signature = "<A-k>",
                next_parameter = "<A-l>",
                previous_parameter = "<A-h>",
            },
        })
    end
end

return M
