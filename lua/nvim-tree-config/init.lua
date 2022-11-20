require('nvim-tree').setup({
    filters = {
        dotfiles = true,
        custom = {
            "bin","obj"
        }
    }
})
