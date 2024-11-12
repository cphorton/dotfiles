return {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
        local icons = require("config.icons").icons
        local lualine = require("lualine")

        local mode = "mode"
        local filetype = { "filetype", icon_only = true }

        local diagnostics = {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            sections = { "error", "warn", "info", "hint" },
            symbols = {
                error = icons.diagnostics.Error,
                hint = icons.diagnostics.Hint,
                info = icons.diagnostics.Info,
                warn = icons.diagnostics.Warning,
            },
            colored = true,
            update_in_insert = false,
            always_visible = false,
        }

        local diff = {
            "diff",
            source = function()
                local gitsigns = vim.b.gitsigns_status_dict
                if gitsigns then
                    return {
                        added = gitsigns.added,
                        modified = gitsigns.changed,
                        removed = gitsigns.removed,
                    }
                end
            end,
            symbols = {
                added = icons.git.added .. " ",
                modified = icons.git.modified .. " ",
                removed = icons.git.removed .. " ",
            },
            colored = true,
            always_visible = false,
        }


        --Show the DAP status
        --comes from here: https://www.reddit.com/r/neovim/comments/1aseug5/is_it_possible_to_have_a_lualine_indicator_that/
        local dap_status = {
            function()
                return require("dap").status()
            end,
            icon = { "", color = { fg = "#e7c664" } }, -- nerd icon.
            cond = function()
                if not package.loaded.dap then
                    return false
                end
                local session = require("dap").session()
                return session ~= nil
            end,
        }



        lualine.setup({
            options = {
                theme = "auto",
                globalstatus = true,
                section_separators = "",
                component_separators = "",
                disabled_filetypes = { statusline = { "dashboard", "lazy", "alpha" } },
            },
            sections = {
                lualine_a = { mode },
                lualine_b = {},
                lualine_c = { "filename" },
                lualine_x = { diff, diagnostics, filetype, dap_status },
                lualine_y = {},
                lualine_z = {},
            },
        })
    end
}
