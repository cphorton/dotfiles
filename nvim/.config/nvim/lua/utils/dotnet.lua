local M = {}

local path = require("plenary.path")


M.get_cs_files = function()

    local cwd = vim.fn.getcwd()

    local cs_files = vim.fs.find(
        function(name, filepath)
            return name:match('.*%.cs$') and not filepath:match("[/\\]obj[/\\]")
        end,
        { path = vim.fn.getcwd(), limit = math.huge, type = 'file' }
    )

--    print(vim.inspect(cs_files))
    return cs_files


end


M.any_unsaved_buffers = function()
    for _, buff_id in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_get_option_value('modified', {buf = buff_id}) then
            return true
        end
    end
    return false
end

return M
