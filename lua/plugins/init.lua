return {
    { "folke/neodev.nvim", opts = {} },
    {dir = "~/Development/neovim/dotnet.nvim", dependencies = {"nvim-lua/plenary.nvim"}},
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
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "BufReadPost", "BufNewFile" },
        opts = {
            -- char = "▏",
            char = "│",
            filetype_exclude = { "help", "alpha", "dashboard", "neo-tree", "Trouble", "lazy" },
            show_trailing_blankline_indent = false,
            show_current_context = false,
        },
    },
    {
        "kdheepak/lazygit.nvim",
        -- optional for floating window border decoration
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
    },
    {'numToStr/Comment.nvim', lazy = false, event = "VeryLazy", config = true},
    {"lewis6991/gitsigns.nvim", config = true },
    {"akinsho/toggleterm.nvim", version = "*", event = "VeryLazy", opts = {
        direction = "float",
        hide_numbers = true,
        open_mapping = [[<c-t>]]
    }, config = true },
    {'ThePrimeagen/harpoon', config = true}
}
