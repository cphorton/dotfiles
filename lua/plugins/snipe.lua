return {
    "leath-dub/snipe.nvim",
    keys = {
        { "<leader>b", function() require("snipe").open_buffer_menu({max_path_width = 2}) end, desc = "Open Snipe buffer menu" }
    },
    opts = {
        sort = "last"
    }
}
