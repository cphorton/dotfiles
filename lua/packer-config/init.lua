return require('packer').startup({function()
	use 'wbthomason/packer.nvim'
    use 'nvim-lua/plenary.nvim'
    use 'navarasu/onedark.nvim'
    use 'antoinemadec/FixCursorHold.nvim'
    use 'EdenEast/nightfox.nvim'
	use 'kyazdani42/nvim-web-devicons'
	use 'nvim-tree/nvim-tree.lua'
	use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}
    use 'nvim-treesitter/playground'
    use 'rcarriga/nvim-notify'
	use 'nvim-lualine/lualine.nvim'
	use 'romgrk/barbar.nvim'
	use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
    use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
    use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
    use 'L3MON4D3/LuaSnip' -- Snippets plugin
	use 'nvim-telescope/telescope.nvim'
	use 'folke/which-key.nvim'
	use 'onsails/lspkind.nvim'
	use 'Issafalcon/lsp-overloads.nvim'
	use 'mfussenegger/nvim-dap'
	use 'rcarriga/nvim-dap-ui'
	use 'theHamsta/nvim-dap-virtual-text'
	use 'rcarriga/cmp-dap'
    use 'akinsho/toggleterm.nvim'
    use 'nvim-telescope/telescope-ui-select.nvim'
    use 'folke/tokyonight.nvim'
    use 'numToStr/Comment.nvim'
    use 'windwp/nvim-autopairs'
    use 'williamboman/mason.nvim'
    use 'williamboman/mason-lspconfig.nvim'
	use 'neovim/nvim-lspconfig'
    use 'Tastyep/structlog.nvim'
    use 'lukas-reineke/indent-blankline.nvim'
    use 'lewis6991/gitsigns.nvim'
    use ({'nvim-neotest/neotest',
        requires = {
            {
                'issafalcon/neotest-dotnet',
            },
        }
    })
    use 'filipdutescu/renamer.nvim'

end,

config={
    max_jobs=10
    }
})
