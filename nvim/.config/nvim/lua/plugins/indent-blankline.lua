return {

    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
        local hooks = require "ibl.hooks"
        -- hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
        -- hooks.register(hooks.type.CURRENT_INDENT_HIGHLIGHT, hooks.builtin.current_indent_highlight_from_extmark)

        --local highlight = {
        --    "RainbowDelimiterRed",
        --     "RainbowDelimiterYellow",
        --   "RainbowDelimiterBlue",
        --    "RainbowDelimiterOrange",
        --    "RainbowDelimiterGreen",
        --    "RainbowDelimiterViolet",
        --    "RainbowDelimiterCyan",
        --}
        local highlight = {
            "RainbowRed",
            "RainbowYellow",
            "RainbowBlue",
            "RainbowOrange",
            "RainbowGreen",
            "RainbowViolet",
            "RainbowCyan",
        }
        hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
            vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#5D3D52" })
            vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#574D47" })
            vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#3B496E" })
            vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#5F4846" })
            vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#455548" })
            vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#443F66" })
            vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#3C5670" })

        end)
        --Set global values that would override the rainbow delimiter values
        --vim.g.rainbow_delimiters = { highlight = highlight }
        require("ibl").setup {
            indent = {
                char = "▏",
                --enabled = true,
                highlight = highlight,
            },
            scope = { highlight = highlight },
        }
        hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
    end,
}

