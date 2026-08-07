  return {
    "folke/tokyonight.nvim",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require("tokyonight").setup({
        on_highlights = function(hl, c)
          -- Give SQL injected into strings (see after/queries/c_sharp/injections.scm)
          -- its own palette so it doesn't blend into the surrounding C#.
          hl["@keyword.sql"] = { fg = c.yellow, italic = true }
          hl["@keyword.conditional.sql"] = { fg = c.yellow, italic = true }
          hl["@keyword.modifier.sql"] = { fg = c.yellow, italic = true }
          hl["@keyword.operator.sql"] = { fg = c.yellow }
          hl["@type.sql"] = { fg = c.teal }
          hl["@type.builtin.sql"] = { fg = c.teal }
          hl["@string.sql"] = { fg = c.cyan }
          hl["@number.sql"] = { fg = c.magenta2 }
          hl["@number.float.sql"] = { fg = c.magenta2 }
          hl["@boolean.sql"] = { fg = c.magenta2 }
          hl["@comment.sql"] = { fg = c.green2, italic = true }
          hl["@function.call.sql"] = { fg = c.magenta }
          -- subtle background behind the whole injected SQL region
          -- (see after/ftplugin/c_sharp.lua)
          hl["SqlInjectionBg"] = { bg = c.blue7 }

          -- dap_quickwatch's expression box uses legacy 'syntax=cs'
          -- highlighting (see lua/dap_quickwatch/init.lua) rather than
          -- treesitter, since the C# grammar wraps any bare expression
          -- with no trailing ';' -- which every QuickWatch expression is
          -- -- in a synthetic ERROR node during error recovery, and
          -- Neovim's treesitter highlighter suppresses captures inside
          -- ERROR nodes. $VIMRUNTIME/syntax/cs.vim correctly `hi def
          -- link`s most of its groups to standard ones (csInteger ->
          -- Number, csComment -> Comment, csType -> Type, ...), which
          -- tokyonight already styles -- but csBraces/csParens (`[]{}`
          -- and `()`, i.e. most of the punctuation in a typical watch
          -- expression like `forecast[0].Where(...)`) are left
          -- undefined for colorschemes to style directly, and tokyonight
          -- doesn't, so they rendered with zero color despite being
          -- correctly identified (confirmed via :highlight csBraces).
          hl["csBraces"] = { link = "Delimiter" }
          hl["csParens"] = { link = "Delimiter" }
        end,
      })
      -- load the colorscheme here
      vim.cmd([[colorscheme tokyonight]])
    end,
  }
