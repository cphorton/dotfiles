local dap = require('dap')

vim.fn.sign_define('DapBreakpoint', { text='', texthl='TSError', linehl='DapBreakpoint', numhl='DapBreakpoint' })
vim.fn.sign_define('DapBreakpointCondition', { text='ﳁ', texthl='TSError', linehl='DapBreakpoint', numhl='DapBreakpoint' })
vim.fn.sign_define('DapBreakpointRejected', { text='', texthl='TSError', linehl='DapBreakpoint', numhl= 'DapBreakpoint' })
vim.fn.sign_define('DapLogPoint', { text='', texthl='TSFloat', linehl='DapLogPoint', numhl= 'DapLogPoint' })
vim.fn.sign_define('DapStopped', { text='', texthl='TSCharacter', linehl='DapStopped', numhl= 'DapStopped' })

local netcoredbgCommand

if vim.fn.has('win32') == 1 then
  netcoredbgCommand = 'c:\\tools\\netcoredbg\\netcoredbg.exe'
elseif vim.fn.has('linux') == 1 then
  netcoredbgCommand = '/usr/bin/netcoredbg'
end

dap.adapters.coreclr = {
  type = 'executable',
  command = netcoredbgCommand,
  args = {'--interpreter=vscode'},
 -- options = {
 --     cwd = 'C:\\Development\\Applications\\OctopusTenantVariableCopy\\OctopusTenantVariableCopy\\bin\\Debug\\net6.0'
 --   }    
}

vim.g.dotnet_build_project = function()

    local default_path = vim.fn.getcwd() .. '/'
    if vim.g['dotnet_last_proj_path'] ~= nil then
        default_path = vim.g['dotnet_last_proj_path']
    end
    local path = vim.fn.input('Path to your *proj file ', default_path, 'file')
    vim.g['dotnet_last_proj_path'] = path
    --local cmd =  'dotnet build -c Debug ' .. path .. nullOutput

    local buildCommand

    if vim.fn.has('win32') == 1 then
        buildCommand =  'dotnet build -c Debug ' .. path .. ' > NUL'
    elseif vim.fn.has('linux') == 1 then
        buildCommand =  'dotnet build -c Debug ' .. path .. ' > /dev/null'
    end

    print('')
    print('Cmd to execute: ' .. buildCommand)
    local f = os.execute(buildCommand)
    if f == 0 then
        print('\nBuild: ✔️ ')
    else
        print('\nBuild: ❌ (code: ' .. f .. ')')
    end
end

vim.g.dotnet_get_dll_path = function()
    local request = function()

        local path

        if vim.fn.has('win32') == 1 then
            path =  '\\bin\\Debug\\'
        elseif vim.fn.has('linux') == 1 then
            path =  '/bin/Debug/'
        end

        return vim.fn.input('Path to dll', vim.fn.getcwd() .. path, 'file')
    end

    if vim.g['dotnet_last_dll_path'] == nil then
        vim.g['dotnet_last_dll_path'] = request()
    else
        if vim.fn.confirm('Do you want to change the path to dll? \n' .. vim.g['dotnet_last_dll_path'], '&yes\n&no', 2) == 1 then
            vim.g['dotnet_last_dll_path'] = request()
        end
    end

    return vim.g['dotnet_last_dll_path']
end

local config = {
    {
        type = "coreclr",
        name = "launch - netcoredbg",
        request = "launch",
        program = function()
            if vim.fn.confirm('Should I recompile first?', '&yes\n&no', 2) == 1 then
                vim.g.dotnet_build_project()
            end
            return vim.g.dotnet_get_dll_path()
        end,
    },
}

dap.configurations.cs = config
dap.configurations.fsharp = config


require("dapui").setup()

require("nvim-dap-virtual-text").setup()

require("cmp").setup({
  enabled = function()
    return vim.api.nvim_buf_get_option(0, "buftype") ~= "prompt"
        or require("cmp_dap").is_dap_buffer()
  end
})

require("cmp").setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
  sources = {
    { name = "dap" },
  },
})
