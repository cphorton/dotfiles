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

    local idx = file_path:match('^.*()' .. sep) - 1

    return file_path:sub(1, idx)
end

M.get_csproj_file_name = function()
    local csproj_path = M.get_csproj_file()
    local sep = path.path.sep

    local index = csproj_path:match('^.*()' .. sep) + 1

    local proj_name = csproj_path:sub(index)

    if (proj_name ~= nil) then
        return proj_name
    end

    return ""
end

M.get_csproj_name = function()
    return M.get_csproj_file_name():gsub(".csproj", "")
end

M.get_namespace = function()
    local buffer_path = vim.api.nvim_buf_get_name(0)
    local csproj_file = M.get_csproj_file()
    local project_path = M.get_folder(M.get_csproj_file())
    local csproj_name = M.get_csproj_name()
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

M.get_target_framework = function(csproj_file)
    --Open file and check if it is valid
    local file = io.open(csproj_file, "r")
    if not file then return nil end

    local target_framework

    --iterate through file lines and look for the target framework
    for line in io.lines(csproj_file) do
        target_framework = line:match("<TargetFramework>(.-)</TargetFramework>")
        if (target_framework ~= nil) then
            break
        end
    end

    file:close()
    return target_framework
end

M.get_path_to_assembly = function()
    local sep = path.path.sep
    local assembly_path = M.get_folder(M.get_csproj_file()) ..
        sep .. "bin" ..
        sep .. "Debug" ..
        sep .. M.get_target_framework(M.get_csproj_file()) ..
        sep .. M.get_csproj_name() .. ".dll"
    return assembly_path
end

return M
