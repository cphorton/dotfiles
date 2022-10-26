require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all"
  ensure_installed = { 
	"c_sharp", 
	"lua",
	"svelte",
	"typescript",
	"sql",
    "css",
    "javascript",
    "html"
  },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,
  highlight = {
    -- `false` will disable the whole extension
    enable = true,
  },
}
