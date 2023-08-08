return {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
        require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/lua/snippets/" })
        vim.keymap.set("n", "<leader><leader>s", "<cmd>source ~/.config/nvim/lua/plugins/luasnip.lua<CR>")

        -- local ls = require("luasnip")
        --
        -- vim.keymap.set({ "i", "s" }, "<c-k>", function()
        --     if ls.expand_or_jumpable() then
        --         ls.expand_or_jump()
        --     end
        -- end, { silent = true })
        --
        -- vim.keymap.set({ "i", "s" }, "<c-j>", function()
        --     if ls.jumpable(-1) then
        --         ls.jump(-1)
        --     end
        -- end, { silent = true })
        --
        -- vim.keymap.set("i", "<c-l>", function()
        --         if ls.choice_active() then
        --             ls.change_choice(1)
        --         end
        --     end,
        --     { desc = "Snippet Choices" })
    end,
    keys = {
    {
      "<tab>",
      function()
        return require("luasnip").jumpable(1) and "<Plug>luasnip-jump-next" or "<tab>"
      end,
      expr = true, silent = true, mode = "i",
    },
    { "<tab>", function() require("luasnip").jump(1) end, mode = "s" },
    { "<s-tab>", function() require("luasnip").jump(-1) end, mode = { "i", "s" } },
    { "<c-tab>", function()
        if (require("luasnip").choice_active()) then
            require("luasnip").change_choice(1)
        end
    end, mode = { "i", "s" } }
  },
    -- keys = function()
    --
    --     local ls = require("luasnip")
    --
    --     return
    --     {
    --         {
    --             "<tab>",
    --             function()
    --                 if (ls.expand_or_jumpable()) then
    --                     ls.expand_or_jump()
    --                 else
    --                     local key = vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
    --                     vim.api.nvim_feedkeys(key, 'i', false)
    --                 end
    --             end,
    --             "i",
    --             desc = "Next option"
    --         },
    --         {
    --             "<S-Tab>",
    --             function() ls.jump(-1) end,
    --             {"s","i"},
    --             desc = "Prev option"
    --         },
    --         {
    --             "<tab>",
    --             function() ls.jump(-1) end,
    --             "s",
    --             desc = "Next option"
    --         }
    --
    --     }
    --end
}
