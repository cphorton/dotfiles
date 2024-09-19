return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    -- or                              , branch = '0.1.x',
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-tree/nvim-web-devicons'
    },
    opts = {
        defaults = {
            mappings = {
                i = {
                    ["<C-k>"] = require("telescope.actions").move_selection_previous,
                    ["<C-j>"] = require("telescope.actions").move_selection_next,
                }
            }
        }
    },
    keys = {
        { "<leader><space>", "<cmd>Telescope find_files<cr>",          desc = "Find Files (root dir)" },
        { "<leader>ff",      "<cmd>Telescope find_files<cr>",          desc = "Find Files (root dir)" },
        { "<leader>fo",      "<cmd>Telescope oldfiles<cr>",            desc = "Find Old Files" },
        { "<leader>fs",      "<cmd>Telescope live_grep<cr>",           desc = "Find String" },
        { "<leader>fc",      "<cmd>Telescope grep_string<cr>",         desc = "Find String Under Cursor" },
        { "<leader>fb",      "<cmd>Telescope buffers<cr>",             desc = "Find Buffers" },
        { "<leader>fd",      "<cmd>Telescope lsp_definitions<cr>",     desc = "Find Definitions" },
        { "<leader>fr",      "<cmd>Telescope lsp_references<cr>",      desc = "Find References" },
        { "<leader>fi",      "<cmd>Telescope lsp_implementations<cr>", desc = "Find Implementations" },

    }
}
