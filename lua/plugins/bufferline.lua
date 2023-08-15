return {
    {
        'akinsho/bufferline.nvim',
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        lazy = true,
        event = "ColorScheme",
        opts = {
            options = {
                diagnostics = "nvim_lsp",
                --Configure line numbers from harpoon
                numbers = function(number_opts)
                    local harpoon = require("harpoon.mark")
                    local buf_name = vim.api.nvim_buf_get_name(number_opts.id)
                    local harpoon_mark = harpoon.get_index_of(buf_name)
                    return harpoon_mark
                end,
                offsets = {
                    {
                        filetype = "neo-tree",
                        text = "Neo-tree",
                        highlight = "Directory",
                        text_align = "left"
                    }
                }
            }
        },
        keys = {
            {"<leader>bc", "<cmd>bd<cr>", desc="Buffer close"},
            {"<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc="Buffer close others"}
        }
    },
}
