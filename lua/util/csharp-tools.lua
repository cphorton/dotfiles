local M = {}

local path = require("plenary.path")

M.get_csproj_file = function()
    --Find csproj files upward
    local projectFiles = vim.fs.find(function(name, _)
            return name:match('.*%.csproj$')
        end,
        {
            upward = true,
            stop = vim.loop.os_homedir(),
            path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
        })

    --Check to see if we find any
    if next(projectFiles) == nil then
        return ""
    end

    return projectFiles[1]
end


M.get_folder = function(file_path)
    local sep = path.path.sep

    local idx = file_path:match('^.*()' .. sep) -1

    return file_path:sub(1, idx)
end

M.get_csproj_name = function()
    local csproj_path = M.get_csproj_file()
    local sep = path.path.sep

    local index = csproj_path:match('^.*()' .. sep) + 1

    local proj_name = csproj_path:sub(index)

    if (proj_name ~= nil) then
        return proj_name
    end

    return ""
end


M.get_namespace = function()
    local buffer_path = vim.api.nvim_buf_get_name(0)
    local csproj_file = M.get_csproj_file()
    local project_path = M.get_folder(M.get_csproj_file())
    local csproj_name = M.get_csproj_name():gsub(".csproj", "")
    local namespace_path = buffer_path:gsub(project_path, "")
    local sep = path.path.sep

    namespace_path = csproj_name .. M.get_folder(namespace_path)
    local namespace = namespace_path:gsub(sep, ".")

    if (namespace == ".") then
        return csproj_name
    end

    return namespace
end

M.get_classname = function()
    --get the name of the current file
    return vim.fn.expand('%:t:r')
end

return M
