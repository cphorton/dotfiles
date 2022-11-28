-- luasnip setup
local luasnip = require 'luasnip'

local lspkind = require('lspkind')

local log = require("structlog")

local logger = log.get_logger("name")

local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end


-- nvim-cmp setup
local cmp = require 'cmp'
cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    --['.'] = cmp.mapping.confirm({behavior = cmp.ConfirmBehavior.Replace, select=true}),
    -- ['.'] = cmp.mapping(function()
    --         local cursor = vim.api.nvim_win_get_cursor(0)
    --         vim.api.nvim_buf_set_text(0, cursor[1], cursor[2], cursor[1], cursor[2], {"."})
    --         end
    --     ),
        -- ['.'] = cmp.mapping(function(fallback)
    --         --Figure out how to also get the dot to be written
    --     if cmp.visible() then
    --         local entry = cmp.get_selected_entry()
    --         if not entry then
	   --          fallback() 
	   --      else
    --             cmp.confirm()
    --         end
    --     else
    --         fallback()
    --     end
    -- end, {"i","s"}),
    -- ['('] = cmp.mapping.complete(),
    -- ['<Space>'] = cmp.mapping.complete(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = false,
    },
    ["<Tab>"] = cmp.mapping(function(fallback)
     if cmp.visible() then
        local entry = cmp.get_selected_entry()
        if not entry then
	        cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
	    else
	        cmp.confirm()
	    end
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      elseif has_words_before() then
        cmp.complete()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),

    }),
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  },
  completion= {
        keyword_length = 1,
        completeopt="menuone"
    },

formatting = {
    format = lspkind.cmp_format({
      mode = 'symbol_text', -- show only symbol annotations
      maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
      ellipsis_char = '...', -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)

      -- The function below will be called before any actual modifications from lspkind
      -- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
      before = function (entry, vim_item)
         return vim_item
      end
    })
  },
}
-- cmp.event:on(
--     'confirm_done',
--      function(evt)
--         -- local line_col_par = vim.api.nvim_win_get_cursor(0)
--         -- local buf_handle = vim.api.nvim_win_get_buf(0) -- get the buffer handler
--         -- nvim_buf_set_text(buf_handle, line_col_par)
--         --
-- --        vim.cmd('normal i.')
--         --vim.notify(vim.json_encode(evt),'info')
--         --vim.pretty_print(evt)
--         print(unpack(evt))
-- --        logger:info(unpack(evt))
--     end
--)

