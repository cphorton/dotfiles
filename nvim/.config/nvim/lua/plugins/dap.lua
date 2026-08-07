return {
    {
        "mfussenegger/nvim-dap",
        config = function()
            local dap = require("dap")

            local icons = require("config.icons").icons

            --Setup autocommand to allow closing of DAP hover using "q" or "esc"
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "dap-float",
                callback = function()
                    vim.api.nvim_buf_set_keymap(0, "n", "q", "<cmd>close!<CR>", { noremap = true, silent = true })
                end
            })

            -- QuickWatch is two floats (input + tree) that must close together,
            -- and needs its own "Add Watch" binding -- so it gets its own
            -- autocmd rather than reusing the single-window "dap-float" one above.
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "dap-quickwatch-*",
                callback = function(args)
                    local qw = require("dap_quickwatch")
                    vim.keymap.set("n", "q", qw.close, { buffer = args.buf, silent = true })
                    vim.keymap.set("n", "<Esc>", qw.close, { buffer = args.buf, silent = true })
                    vim.keymap.set("n", "<leader>a", qw.add_watch, { buffer = args.buf, silent = true })
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
            { "<leader>dQ", function() require("dap_quickwatch").open(vim.fn.expand('<cword>')) end, desc = "QuickWatch" },
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
