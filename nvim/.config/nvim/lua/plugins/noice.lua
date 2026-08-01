return
{
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
   lsp = {
    -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
    },
    -- noice renders its own signature help popup by default (enabled = true), entirely
    -- independent of ray-x/lsp_signature.nvim (see lua/plugins/lsp-signature.lua) -- the
    -- two were both showing simultaneously ("two signatures" duplicate popups) with no
    -- awareness of each other. lsp_signature.nvim owns this now (it supports cycling
    -- through overloads, which noice's signature view does not), so disable noice's.
    signature = { enabled = false },
  },
  -- you can enable a preset for easier configuration
  presets = {
    bottom_search = true, -- use a classic bottom cmdline for search
    command_palette = true, -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false, -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = false, -- add a border to hover docs and signature help
  },
     
    },
    dependencies = {
        -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
        "MunifTanjim/nui.nvim",
        -- OPTIONAL:
        --   `nvim-notify` is only needed, if you want to use the notification view.
        --   If not available, we use `mini` as the fallback
        "rcarriga/nvim-notify",
    }
}




