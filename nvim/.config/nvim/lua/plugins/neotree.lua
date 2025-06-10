return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
        "MunifTanjim/nui.nvim",
        -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    opts = function()
        return {
            enable_diagnostics = true,
            default_component_configs = {
                git_status = {
                    symbols = {
                        added = "",
                        modified = "",
                        deleted = "",
                        renamed = "",
                        untracked = "",
                        ignored = "",
                        unstaged = "",
                        staged = "",
                        conflict = "",
                    },
                },
            },
            window = {
                mappings = {
                    ['v'] = "expand_all_nodes",
                    ['e'] = function() vim.api.nvim_exec('Neotree focus filesystem float', true) end,
                    ['b'] = function() vim.api.nvim_exec('Neotree focus buffers float', true) end,
                    ['g'] = function() vim.api.nvim_exec('Neotree focus git_status float', true) end,
                    ['p'] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
                }
            }
        }
    end,
    keys = {
        { "<leader>ft", "<cmd>Neotree float reveal<cr>", desc = "Neotree Popup reveal" },
    }
}
