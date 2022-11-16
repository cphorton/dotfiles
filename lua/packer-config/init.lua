return require('packer').startup(function()
	use 'wbthomason/packer.nvim'
    use 'navarasu/onedark.nvim'
    use 'EdenEast/nightfox.nvim'
	use 'kyazdani42/nvim-web-devicons'
	use 'nvim-tree/nvim-tree.lua'
	use 'neovim/nvim-lspconfig'
	use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}
	use 'rcarriga/nvim-notify'
	use 'nvim-lualine/lualine.nvim'
	use 'romgrk/barbar.nvim'
	use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
    use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
    use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
    use 'L3MON4D3/LuaSnip' -- Snippets plugin
	use {'nvim-telescope/telescope.nvim', requires = { {'nvim-lua/plenary.nvim'} } }
	use 'folke/which-key.nvim'
	use 'onsails/lspkind.nvim'
	use 'Issafalcon/lsp-overloads.nvim'
	use 'mfussenegger/nvim-dap'
	use 'rcarriga/nvim-dap-ui'
	use 'theHamsta/nvim-dap-virtual-text'
	use 'rcarriga/cmp-dap'
    use 'akinsho/toggleterm.nvim'
    use {
        'kosayoda/nvim-lightbulb',
        requires = 'antoinemadec/FixCursorHold.nvim',
    }
    use 'nvim-telescope/telescope-ui-select.nvim' 
end)
