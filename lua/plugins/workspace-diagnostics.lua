return {
    "artemave/workspace-diagnostics.nvim",
    setup = function()
        vim.api.nvim_set_keymap('n', '<leader>wd', '', {
            noremap = true,
            callback = function()
                for _, client in ipairs(vim.lsp.buf_get_clients()) do
                    require("workspace-diagnostics").populate_workspace_diagnostics(client, 0)
                end
            end
        })
    end
}
