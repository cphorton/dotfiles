return {
    "artemave/workspace-diagnostics.nvim",
    config = function()

        local cs_files_function = require("utils.dotnet").get_cs_files
        require("workspace-diagnostics").setup({
--            workspace_files = cs_files_function,
            debug = true
        })
    end,
    keys = {
        {
            "<leader>x",
            mode = { "n" },
            function()
                for _, client in ipairs(vim.lsp.get_clients()) do
                    require("workspace-diagnostics").populate_workspace_diagnostics(client, 0)
                end
            end
        }
    }
}
