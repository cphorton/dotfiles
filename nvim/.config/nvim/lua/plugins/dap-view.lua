return {
    {
        "igorlfs/nvim-dap-view",
        ---@module 'dap-view'
        ---@type dapview.Config
        opts = {},
        keys = {
            {
                "<leader>dwt",
                function()
                    local widgets = require("dap.ui.widgets")
                    widgets.float_element(widgets.scopes, { border = "rounded" })
                end,
                desc = "DAP Scopes",
            },
        }
    },
}
