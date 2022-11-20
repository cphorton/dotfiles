require('nvim-tree').setup({
    filters = {
        dotfiles = true,
        custom = {
            "bin","obj"
        }
    }
})

local api = require("nvim-tree.api")
api.events.subscribe(api.events.Event.FileCreated, function(file)
  vim.cmd("edit " .. file.fname)
end)
