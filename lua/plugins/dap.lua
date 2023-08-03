return {
{
  "mfussenegger/nvim-dap",

  dependencies = {

    -- fancy UI for the debugger
    {
      "rcarriga/nvim-dap-ui",
      -- stylua: ignore
      keys = {
        { "<leader>du", function() require("dapui").toggle({ }) end, desc = "Dap UI" },
        { "<leader>de", function() require("dapui").eval() end, desc = "Eval", mode = {"n", "v"} },
      },
      opts = {},
      config = function(_, opts)
        local dap = require("dap")
        local dapui = require("dapui")
        dapui.setup(opts)
        dap.listeners.after.event_initialized["dapui_config"] = function()
          dapui.open({})
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
          dapui.close({})
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
          dapui.close({})
        end
      end,
    },

    -- virtual text for the debugger
    {
      "theHamsta/nvim-dap-virtual-text",
      opts = {},
    },

    -- which key integration
    {
      "folke/which-key.nvim",
      optional = true,
      opts = {
        defaults = {
          ["<leader>d"] = { name = "+debug" },
          ["<leader>da"] = { name = "+adapters" },
        },
      },
    },

    -- mason.nvim integration
    {
      "jay-babu/mason-nvim-dap.nvim",
      dependencies = "mason.nvim",
      cmd = { "DapInstall", "DapUninstall" },
      opts = {
        -- Makes a best effort to setup the various debuggers with
        -- reasonable debug configurations
        automatic_installation = true,

        -- You can provide additional configuration to the handlers,
        -- see mason-nvim-dap README for more information
        handlers = {},

        -- You'll need to check that you have the required things installed
        -- online, please don't ask me how to install them :)
        ensure_installed = {
          -- Update this to ensure that you have the debuggers for the langs you want
          "coreclr"
        },
      },
    },
  },

  -- stylua: ignore
  keys = {
    { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
    { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
    { "<F5>", function() require("dap").continue() end, desc = "Continue" },
    { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
    { "<leader>dg", function() require("dap").goto_() end, desc = "Go to line (no execute)" },
    { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
    { "<F11>", function() require("dap").step_into() end, desc = "Step Into" },
    { "<leader>dj", function() require("dap").down() end, desc = "Down" },
    { "<leader>dk", function() require("dap").up() end, desc = "Up" },
    { "<leader>dl", function() require("dap").run_last() end, desc = "Run Last" },
    { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
    { "<F12>", function() require("dap").step_out() end, desc = "Step Out" },
    { "<leader>dO", function() require("dap").step_over() end, desc = "Step Over" },
    { "<F10>", function() require("dap").step_over() end, desc = "Step Over" },
    { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },
    { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
    { "<leader>ds", function() require("dap").session() end, desc = "Session" },
    { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
    { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
  },

  config = function()
    local Config = require("config")
    vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

    for name, sign in pairs(Config.icons.dap) do
      sign = type(sign) == "table" and sign or { sign }
      vim.fn.sign_define(
        "Dap" .. name,
        { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
      )
    end

    local dap = require("dap")

    local masonPath = "/mason/bin/netcoredbg"
    --  if vim.fn.has("win32") == 1 then
    --    masonPath = "\\mason\\bin\\netcoredbg.exe"
    --  elseif vim.fn.has("linux") == 1 then
    --    masonPath = "/mason/bin/netcoredbg"
    --  end

    local netcoredbgCommand = vim.fn.stdpath('data')..masonPath

    dap.adapters.coreclr = {
        type = "executable",
        command = netcoredbgCommand,
        args = { "--interpreter=vscode" },
        --options = {
        --    cwd = 'C:\\Development\\Applications\\OctopusTenantVariableCopy\\OctopusTenantVariableCopy\\bin\\Debug\\net6.0'
        --  }
      }

vim.g.dotnet_build_project = function()
        local default_path = vim.fn.getcwd() .. "/"
        if vim.g["dotnet_last_proj_path"] ~= nil then
          default_path = vim.g["dotnet_last_proj_path"]
        end
        local path = vim.fn.input("Path to your *proj file ", default_path, "file")
        vim.g["dotnet_last_proj_path"] = path
        --local cmd =  'dotnet build -c Debug ' .. path .. nullOutput

        local buildCommand

        if vim.fn.has("win32") == 1 then
          buildCommand = "dotnet build -c Debug " .. path .. " > NUL"
        elseif vim.fn.has("linux") == 1 then
          buildCommand = "dotnet build -c Debug " .. path .. " > /dev/null"
        end

        print("")
        print("Cmd to execute: " .. buildCommand)
        local f = os.execute(buildCommand)
        if f == 0 then
          print("\nBuild: ✔️ ")
        else
          print("\nBuild: ❌ (code: " .. f .. ")")
        end
      end

      vim.g.dotnet_get_dll_path = function()
        local request = function()
          local path

          if vim.fn.has("win32") == 1 then
            path = "\\bin\\Debug\\"
          elseif vim.fn.has("linux") == 1 then
            path = "/bin/Debug/"
          end

          return vim.fn.input("Path to dll", vim.fn.getcwd() .. path, "file")
        end

        if vim.g["dotnet_last_dll_path"] == nil then
          vim.g["dotnet_last_dll_path"] = request()
        else
          if
            vim.fn.confirm("Do you want to change the path to dll? \n" .. vim.g["dotnet_last_dll_path"], "&yes\n&no", 2)
            == 1
          then
            vim.g["dotnet_last_dll_path"] = request()
          end
        end

        return vim.g["dotnet_last_dll_path"]
      end

      local config = {
        {
          type = "coreclr",
          name = "launch - netcoredbg",
          request = "launch",
          program = function()
            if vim.fn.confirm("Should I recompile first?", "&yes\n&no", 2) == 1 then
              vim.g.dotnet_build_project()
            end
            return vim.g.dotnet_get_dll_path()
          end,
        },
      }

      dap.configurations.cs = config
      dap.configurations.fsharp = config

  end,
},

{
  "rcarriga/nvim-dap-ui",
  -- stylua: ignore
  keys = {
    { "<leader>du", function() require("dapui").toggle({ }) end, desc = "Dap UI" },
    { "<leader>de", function() require("dapui").eval() end, desc = "Eval", mode = {"n", "v"} },
  },
  opts = {},
  config = function(_, opts)
    local dap = require("dap")
    local dapui = require("dapui")
    dapui.setup(opts)
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open({})
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close({})
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close({})
    end
  end,
},

{
  "theHamsta/nvim-dap-virtual-text",
  opts = {},
}






}
