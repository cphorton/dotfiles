vim.cmd [[highlight RainbowLineYellow guifg=#574D47 gui=nocombine]]
vim.cmd [[highlight RainbowLineViolet guifg=#443F66 gui=nocombine]]
vim.cmd [[highlight RainbowLineOrange guifg=#5F4846 gui=nocombine]]
vim.cmd [[highlight RainbowLineGreen guifg=#455548 gui=nocombine]]
vim.cmd [[highlight RainbowLineCyan guifg=#3C5670 gui=nocombine]]
vim.cmd [[highlight RainbowLineBlue guifg=#3B496E gui=nocombine]]
vim.cmd [[highlight RainbowLineRed guifg=#5D3D52 gui=nocombine]]


return {
    {
        "lukas-reineke/indent-blankline.nvim",
        dependencies = {
            "HiPhish/rainbow-delimiters.nvim",
        },
        event = { "BufReadPost", "BufNewFile" },
        opts = {
            -- char = "▏",
            char = "│",
            filetype_exclude = { "help", "alpha", "dashboard", "neo-tree", "Trouble", "lazy" },
            show_trailing_blankline_indent = false,
            show_current_context = false,
                space_char_blankline = " ",
                char_highlight_list = {
                    'RainbowLineRed',
                    'RainbowLineYellow',
                    'RainbowLineBlue',
                    'RainbowLineOrange',
                    'RainbowLineGreen',
                    'RainbowLineViolet',
                    'RainbowLineCyan',
                }

        },
        config = true
    },
}
