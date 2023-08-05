require("config.options")
require("config.lazy")

vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    callback = function()
  --      require("config.autocmds")
        require("config.keymaps")
    end,
})



--local path = require("plenary.path")


local result = vim.fs.find('*.csproj', {
       upward = true,
       stop = vim.loop.os_homedir(),
       path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
     })


print(vim.inspect(result))
