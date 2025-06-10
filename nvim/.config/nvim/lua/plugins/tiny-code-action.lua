return {
    "rachartier/tiny-code-action.nvim",
    dependencies = {
        {"nvim-lua/plenary.nvim"},
              -- .. or via snacks
        {
          "folke/snacks.nvim",
          opts = {
            terminal = {},
          }
        }
    },
    event = "LspAttach",
    opts = {
        picker = { "snacks" }
    },
}
