return {
    {
        "mfussenegger/nvim-dap",
        config = function()
            local dap = require("dap")
            if not dap.adapters["netcoredbg"] then
                require("dap").adapters["netcoredbg"] = {
                    type = "executable",
                    command = vim.fn.exepath("netcoredbg"),
                    args = { "--interpreter=vscode" },
                    -- console = "internalConsole",
                    options = {
                        detached = false
                    }
                }
            end

            local icons = require("config.icons").icons

            --Setup autocommand to allow closing of DAP hover using "q" or "esc"
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "dap-float",
                callback = function()
                    vim.api.nvim_buf_set_keymap(0, "n", "q", "<cmd>close!<CR>", { noremap = true, silent = true })
                end
            })

            vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
            vim.api.nvim_set_hl(0, "DapBreakpointLine", { bg = "#3b1119"--[[ , fg = "#c53b53"  ]] })

            for name, sign in pairs(icons.dap) do
                sign = type(sign) == "table" and sign or { sign }
                vim.fn.sign_define(
                    "Dap" .. name,
                    { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
                )
            end


            local dotnet = require("easy-dotnet")
            local debug_dll = nil
            local function ensure_dll()
                if debug_dll ~= nil then
                    return debug_dll
                end
                local dll = dotnet.get_debug_dll()
                debug_dll = dll
                return dll
            end

            for _, lang in ipairs({ "cs", "fsharp", "vb" }) do
                dap.configurations[lang] = {
                    {
                        log_level = "DEBUG",
                        type = "netcoredbg",
                        justMyCode = false,
                        stopAtEntry = false,
                        name = "Default",
                        request = "launch",
                        env = function()
                            local dll = ensure_dll()
                            local vars = dotnet.get_environment_variables(dll.project_name, dll.relative_project_path)
                            return vars or nil
                        end,
                        program = function()
                            require("overseer").enable_dap()
                            local dll = ensure_dll()
                            return dll.relative_dll_path
                        end,
                        cwd = function()
                            local dll = ensure_dll()
                            return dll.relative_project_path
                        end,
                        preLaunchTask = "Build .NET App With Spinner",
                    },
                }

                dap.listeners.before["event_terminated"]["easy-dotnet"] = function()
                    debug_dll = nil
                end
            end
        end,

        keys = {
            {
                "<leader>dB",
                function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end,
                desc = "Breakpoint Condition"
            },
            { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
            { "<leader>dc", function() require("dap").continue() end,          desc = "Continue" },
            { "<F5>",       function() require("dap").continue() end,          desc = "Continue" },
            { "<leader>dC", function() require("dap").run_to_cursor() end,     desc = "Run to Cursor" },
            { "<leader>dg", function() require("dap").goto_() end,             desc = "Go to line (no execute)" },
            --{ "<leader>di", function() require("dap").step_into() end,         desc = "Step Into" },
            { "<F11>",      function() require("dap").step_into() end,         desc = "Step Into" },
            { "<leader>dj", function() require("dap").down() end,              desc = "Down" },
            { "<leader>dk", function() require("dap").up() end,                desc = "Up" },
            { "<leader>dl", function() require("dap").run_last() end,          desc = "Run Last" },
            --{ "<leader>do", function() require("dap").step_out() end,          desc = "Step Out" },
            { "<F12>",      function() require("dap").step_out() end,          desc = "Step Out" },
            --{ "<leader>dO", function() require("dap").step_over() end,         desc = "Step Over" },
            { "<F10>",      function() require("dap").step_over() end,         desc = "Step Over" },
            { "<leader>dp", function() require("dap").pause() end,             desc = "Pause" },
            { "<leader>dr", function() require("dap").repl.toggle({height = 10}) end,       desc = "Toggle REPL" },
            { "<leader>ds", function() require("dap").session() end,           desc = "Session" },
            { "<leader>dt", function() require("dap").terminate() end,         desc = "Terminate" },
            { "<leader>di", function() require("dap.ui.widgets").hover() end,  desc = "Inspect" },
        },
    },
    {
        "rcarriga/nvim-dap-ui",
        dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
        -- stylua: ignore
        keys = {
            { "<leader>du", function() require("dapui").toggle({}) end,   desc = "Dap UI" },
            { "<leader>de", function()
                require("dapui").eval()
                require("dapui").eval()
            end,                                                         desc = "Eval", mode = { "n", "v" } },
            { "<leader>dv", function()
                require("dapui").float_element('scopes')
                require("dapui").float_element('scopes')
            end,                                                         desc = "Local variables", mode = { "n", "v" } },
            { "<leader>dw", function()
                require("dapui").float_element('watches')
                require("dapui").float_element('watches')
            end,                                                         desc = "Watch values", mode = { "n", "v" } },
            { "<leader>daw", function()
                require('dapui').elements.watches.add(vim.fn.expand('<cword>'))
            end, desc= "Add Watch", mode = { "n", "v" }}
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
    }
}
