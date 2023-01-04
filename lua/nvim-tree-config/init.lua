
local gheight = vim.api.nvim_list_uis()[1].height
local gwidth = vim.api.nvim_list_uis()[1].width

local bwidth = vim.fn.winwidth(0)
local bheight = vim.fn.winheight(0)



local widthPercent = 0.5
local heightPercent = 0.8

local width = math.floor(bwidth * widthPercent)
local height = math.floor(bheight * heightPercent)



require('nvim-tree').setup({
    filters = {
        dotfiles = true,
        custom = {
            "bin","obj"
        }
    },
    view = {
       side = 'left'
    }
    -- view = {
    --     float = {
    --         enable = true,
    --         open_win_config = {
    --             relative = "editor",
    --             width = width,
    --             height = height,
    --             row = (gheight - height) * 0.5,
    --             col = (gwidth - width) * 0.5,
    --         }
    --     }
    -- }
})

local api = require("nvim-tree.api")
api.events.subscribe(api.events.Event.FileCreated, function(file)
  vim.cmd("edit " .. file.fname)
end)
