return {
    { "folke/neodev.nvim",                      opts = {} },
    { dir = "~/Development/neovim/dotnet.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
    {
        "nvim-lualine/lualine.nvim",
        lazy = false,
        priority = 700,
        config = true,
        opts = {
            options = {
                disabled_filetypes = { statusline = { "dashboard", "alpha" } }
            },
            extensions = { "neo-tree" }

        }
    },
    -- {
    --     'goolord/alpha-nvim',
    --     event = "VimEnter",
    --     dependencies = { 'nvim-tree/nvim-web-devicons' },
    --     config = function()
    --         require 'alpha'.setup(require 'alpha.themes.startify'.config)
    --     end
    -- },
    {
        "kdheepak/lazygit.nvim",
        -- optional for floating window border decoration
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
    },
    { 'numToStr/Comment.nvim',   lazy = false,  event = "VeryLazy", config = true },
    { "lewis6991/gitsigns.nvim", config = true, event = "VeryLazy" },
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        event = "VeryLazy",
        opts = {
            direction = "float",
            hide_numbers = true,
            open_mapping = [[<c-t>]]
        },
        config = true
    },
    {
        'ThePrimeagen/harpoon',
        config = true,
        keys = {
            { "<leader>hm", function() require('harpoon.mark').add_file() end,        desc = "Harpoon Mark" },
            { "<leader>hh", function() require('harpoon.ui').toggle_quick_menu() end, desc = "Harpoon UI" },
            { "<leader>h1", function() require("harpoon.ui").nav_file(1) end,         desc = "Harpoon File 1" },
            { "<leader>h2", function() require('harpoon.ui').nav_file(2) end,         desc = "Harpoon File 2" },
            { "<leader>h3", function() require('harpoon.ui').nav_file(3) end,         desc = "Harpoon File 3" },
            { "<leader>h4", function() require('harpoon.ui').nav_file(4) end,         desc = "Harpoon File 4" },
            { "<leader>hj", function() require("harpoon.ui").nav_next() end,          desc = "Harpoon Next File" },
            { "<leader>hn", function() require("harpoon.ui").nav_prev() end,          desc = "Harpoon Previous File" },
            { "<leader>1",  function() require("harpoon.ui").nav_file(1) end,         desc = "Harpoon File 1" },
            { "<leader>2",  function() require('harpoon.ui').nav_file(2) end,         desc = "Harpoon File 2" },
            { "<leader>3",  function() require('harpoon.ui').nav_file(3) end,         desc = "Harpoon File 3" },
            { "<leader>4",  function() require('harpoon.ui').nav_file(4) end,         desc = "Harpoon File 4" },
        }
    }
}
