return {
    "nvim-treesitter/nvim-treesitter",
    -- Pinned: nvim-treesitter's `master` branch is unmaintained/archived. The eventual
    -- real fix is migrating to the `main` branch rewrite, which changes the setup API
    -- and drops commands like :TSInstallInfo -- deliberately not done here.
    commit = "42fc28ba918343ebfd5565147a42a26580579482",
    build = ":TSUpdate",
    config = function ()
      local configs = require("nvim-treesitter.configs")

      configs.setup({
          ensure_installed = { "c_sharp", "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "javascript", "html" },
          sync_install = false,
          highlight = { enable = true },
          indent = { enable = true },
        })

      -- Neovim 0.12 core changed TSNode handling in a way that makes markdown's
      -- "set-lang-from-info-string!" injection directive (used to highlight fenced
      -- code blocks, e.g. the ```cs blocks in Roslyn hover/signature popups, with the
      -- right language) crash with "attempt to call method 'range' (a nil value)",
      -- taking down the whole treesitter highlighter via the decoration provider.
      -- This isn't fixed by pinning nvim-treesitter (the query itself hasn't changed
      -- in ages -- it's a core regression), and won't be fixed upstream since `master`
      -- is archived. Re-register the same directive wrapped in pcall: on the rare
      -- transient failure we just skip injecting a language for that one code fence
      -- instead of crashing highlighting for the whole buffer.
      local injection_language_aliases = { ex = "elixir", pl = "perl", sh = "bash", uxn = "uxntal", ts = "typescript" }
      local function safe_get_parser_from_info_string(injection_alias)
        local match = vim.filetype.match({ filename = "a." .. injection_alias })
        return match or injection_language_aliases[injection_alias] or injection_alias
      end

      vim.treesitter.query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
        pcall(function()
          local capture_id = pred[2]
          local node = match[capture_id]
          if not node then
            return
          end
          local injection_alias = vim.treesitter.get_node_text(node, bufnr):lower()
          metadata["injection.language"] = safe_get_parser_from_info_string(injection_alias)
        end)
      end, { force = true, all = false })
    end
 }
