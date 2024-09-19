local type_dot = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_buf_set_text(0, cursor[1], cursor[2], cursor[1], cursor[2], { "." })
end

return {
    "hrsh7th/nvim-cmp",
    version = false, -- last release is way too old
    event = "InsertEnter",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "saadparwaiz1/cmp_luasnip",
    },
    opts = function()
        vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
        local cmp = require("cmp")
        -- local defaults = require("cmp.config.default")()

        -- Taken from https://github.com/hrsh7th/nvim-cmp/discussions/1618
        -- callback whenever cmp menu is opened
        cmp.event:on("menu_opened", function()
            -- autocmd triggered before a character is inserted
            vim.api.nvim_create_autocmd("InsertCharPre", {
                callback = function(_)
                    -- if no entry is selected - do nothing
                    -- local complete_keys = { ".", " ", "(","<" }
                    local entry = cmp.get_selected_entry()
                    if (entry ~= nil) then

                        -- print(vim.inspect(entry.source))
                        -- store the to-be inserted char
                        local c = vim.v.char
                        -- clear the to-be inserted char
                        vim.v.char = ""
                        -- vim schedule to circumvent the textlock
                        if (c == "." or c == "(" or c == "<") then
                            vim.schedule(function()
                                -- confirm cmp selection - i. e. insert
                                cmp.confirm({ select = false })
                                -- insert the stored char
                                vim.api.nvim_feedkeys(c, "n", false)
                            end)
                        else
                            vim.api.nvim_feedkeys(c, "n", false)
                        end
                    end
                end,
                once = true,
            })
        end)


        return {
            completion = {
                completeopt = "menu,menuone,noinsert",
            },
            --snippet = {
            --    expand = function(args)
            --        require("luasnip").lsp_expand(args.body)
            --    end,
            --},
            mapping = cmp.mapping.preset.insert({
                ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
                ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
                ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                ["<C-f>"] = cmp.mapping.scroll_docs(4),
                ["<C-Space>"] = cmp.mapping.complete(),
                -- ["."] = cmp.mapping(cmp.mapping.complete({behavior = cmp.SelectBehavior.Insert}),{"i","s"}),
                -- ["."] = cmp.mapping.confirm({ select = true}),
                ["<C-e>"] = cmp.mapping.abort(),
                ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
                ["<S-CR>"] = cmp.mapping.confirm({
                    behavior = cmp.ConfirmBehavior.Replace,
                    select = true,
                }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
            }),
            sources = cmp.config.sources({
                { name = "nvim_lsp" },
                --{ name = "luasnip" },
                { name = "buffer" },
                { name = "path" },
            }),
            formatting = {
                format = function(_, item)
                    local icons = require("config.icons").icons.kinds
                    if icons[item.kind] then
                        item.kind = icons[item.kind] .. item.kind
                    end
                    return item
                end,
            },
            window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
            }
--            experimental = {
--                ghost_text = {
--                    hl_group = "CmpGhostText",
--                },
--            },
--            -- sorting = defaults.sorting,
        }
    end,
    config = function(_, opts)
        local cmp = require("cmp")
        cmp.setup(opts)
        cmp.setup.cmdline({ "/", "?" }, {
            mapping = cmp.mapping.preset.cmdline(),
            sources = {
                { name = "buffer" },
            },
        })
        cmp.setup.cmdline(":", {
            mapping = cmp.mapping.preset.cmdline(),
            sources = cmp.config.sources({
                { name = "path" },
            }, {
                { name = "cmdline" },
            }),
        })
    end,
}




-- return {
--     "hrsh7th/nvim-cmp",
--     event = "BufReadPre",
--     dependencies = {
--         "hrsh7th/cmp-nvim-lsp",
--         "hrsh7th/cmp-buffer",
--         "hrsh7th/cmp-cmdline",
--         "hrsh7th/cmp-path",
--         "hrsh7th/cmp-nvim-lsp-signature-help",
--         "saadparwaiz1/cmp_luasnip",
--         {
--             "zbirenbaum/copilot-cmp",
--             config = function()
--                 require("copilot_cmp").setup()
--             end,
--         },
--     },
--     opts = function()
--         local cmp = require("cmp")
--
--         local Config = require("config")
--
--         local cmp_kinds = Config.icons.kinds
--         --local cmp_kinds = require("util").cmp_kinds
--
--         --Set Icons
--         local has_words_before = function()
--             if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
--                 return false
--             end
--             local line, col = vim.F.unpack_len(vim.api.nvim_win_get_cursor(0))
--             return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
--         end
--
--         local luasnip = require("luasnip")
--
--         return {
--             snippet = {
--                 expand = function(args)
--                     luasnip.lsp_expand(args.body)
--                 end,
--             },
--             formatting = {
--                 format = function(entry, vim_item)
--                     if vim.tbl_contains({ "path" }, entry.source.name) then
--                         local icon, hl_group = require("nvim-web-devicons").get_icon(entry:get_completion_item().label)
--                         if icon then
--                             vim_item.kind = icon
--                             vim_item.kind_hl_group = hl_group
--                             return vim_item
--                         end
--                     end
--                     vim_item.kind = (cmp_kinds[vim_item.kind] or "") .. vim_item.kind
--
--                     return vim_item
--                 end,
--             },
--             mapping = cmp.mapping.preset.insert({
--                 ["<C-p>"] = cmp.mapping.select_prev_item(),
--                 ["<C-n>"] = cmp.mapping.select_next_item(),
--                 ["<C-d>"] = cmp.mapping.scroll_docs(-4),
--                 ["<C-f>"] = cmp.mapping.scroll_docs(4),
--                 ["<C-Space>"] = cmp.mapping.complete(),
--                 ["<C-e>"] = cmp.mapping.close(),
--                 ["<CR>"] = cmp.mapping.confirm({
--                     select = false,
--                 }),
--                 ["<Tab>"] = cmp.mapping(function(fallback)
--                     if cmp.visible() then
--                         cmp.select_next_item()
--                     elseif luasnip.expand_or_locally_jumpable() then
--                         luasnip.expand_or_jump()
--                     elseif has_words_before() then
--                         cmp.complete()
--                     else
--                         fallback()
--                     end
--                 end, { "i", "s" }),
--                 ["<S-Tab>"] = cmp.mapping(function(fallback)
--                     if cmp.visible() then
--                         cmp.select_prev_item()
--                     elseif luasnip.jumpable(-1) then
--                         luasnip.jump(-1)
--                     else
--                         fallback()
--                     end
--                 end, { "i", "s" }),
--             }),
--             sources = {
--                 { name = "nvim_lsp" },
--                 --{ name = "nvim_lsp_signature_help" },
--                 { name = "luasnip" },
--                 --{ name = "copilot" },
--                 { name = "path" },
--                 { name = "buffer" },
--             },
--             window = {
--                 completion = cmp.config.window.bordered(),
--                 documentation = cmp.config.window.bordered(),
--             },
--             experimental = { ghost_text = {
--                 hl_group = "LspCodeLens",
--             } },
--         }
--     end,
--     config = function(_, opts)
--         local cmp = require("cmp")
--         cmp.setup(opts)
--         cmp.setup.cmdline({ "/", "?" }, {
--             mapping = cmp.mapping.preset.cmdline(),
--             sources = {
--                 { name = "buffer" },
--             },
--         })
--         cmp.setup.cmdline(":", {
--             mapping = cmp.mapping.preset.cmdline(),
--             sources = cmp.config.sources({
--                 { name = "path" },
--             }, {
--                 { name = "cmdline" },
--             }),
--         })
--     end,
-- }
--

