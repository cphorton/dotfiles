

return {
  'saghen/blink.cmp',
  -- optional: provides snippets for the snippet source
  dependencies = { 'rafamadriz/friendly-snippets' },

  -- use a release tag to download pre-built binaries
  version = '1.*',
  -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
  -- build = 'cargo build --release',
  -- If you use nix, you can build from source using latest nightly rust with:
  -- build = 'nix run .#build-plugin',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
    -- 'super-tab' for mappings similar to vscode (tab to accept)
    -- 'enter' for enter to accept
    -- 'none' for no mappings
    --
    -- All presets have the following mappings:
    -- C-space: Open menu or open docs if already open
    -- C-n/C-p or Up/Down: Select next/previous item
    -- C-e: Hide menu
    -- C-k: Toggle signature help (if signature.enabled = true)
    --
    -- See :h blink-cmp-config-keymap for defining your own keymap
    keymap = {
            preset = 'super-tab',
            ["<CR>"] = { "accept" , "fallback"},
            -- Visual Studio-style dot chaining: if the completion menu is open,
            -- "." accepts the selected item, then types "." once the accept has
            -- actually finished (via the callback, not a racing fallback keypress),
            -- so the next level (e.g. member access on the type just inserted) triggers.
            ["."] = {
                function(cmp)
                    if not cmp.is_menu_visible() then
                        return false
                    end
                    cmp.select_and_accept({
                        callback = function()
                            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(".", true, true, true), "n", true)
                        end,
                    })
                    return true
                end,
                "fallback",
            },
        },
        -- blink's own signature help can't cycle overloads (unimplemented upstream);
        -- ray-x/lsp_signature.nvim (see lua/plugins/lsp-signature.lua) owns <C-k> instead.


    enabled = function() return not vim.tbl_contains({ "neonuget" }, vim.bo.filetype) end,

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono'
    },

    -- (Default) Only show the documentation popup when manually triggered
    completion = { documentation = { auto_show = false } },

    -- Default list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    sources = {
      default = { 'lsp', 'easy-dotnet', 'path', 'snippets', 'buffer' },
        -- nvim-dap sets 'omnifunc' on the REPL buffer to its own completion
        -- (locals, expression members, etc. from the live debug session),
        -- but that omnifunc uses Vim's classic *async* completion protocol
        -- (returns -2, then calls vim.fn.complete() itself later once the
        -- debug adapter responds). Blink's built-in "omni" source doesn't
        -- implement that half of the protocol and silently drops those
        -- results, so real member/expression completions (e.g.
        -- `forecast[0].` -> TemperatureC) never showed up -- only whatever
        -- completed synchronously did. `dap_repl` (see
        -- lua/dap_repl_completion/init.lua) bridges that async protocol
        -- into blink directly, so "buffer" is no longer needed here.
        per_filetype = {
          ["dap-repl"] = { "dap_repl" },
        },
        providers = {
          ["easy-dotnet"] = {
            name = "easy-dotnet",
            enabled = true,
            module = "easy-dotnet.completion.blink",
            score_offset = 10000,
            async = true,
          },
          dap_repl = {
            name = "dap_repl",
            module = "dap_repl_completion",
            async = true,
          },
        },
    },

    -- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
    -- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
    -- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
    --
    -- See the fuzzy documentation for more information
    fuzzy = { implementation = "prefer_rust_with_warning" },
    signature = { enabled = false }
  },
  opts_extend = { "sources.default" }
}
