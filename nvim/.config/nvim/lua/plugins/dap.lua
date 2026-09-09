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

            -- Surface Kestrel's startup "Now listening on: <url>" line(s) as
            -- a notification. When a debug adapter sends a runInTerminal
            -- reverse-request (as easy-dotnet's "attach" config does via its
            -- `console` option), nvim-dap core (session.lua:run_in_terminal)
            -- ALWAYS spawns the debuggee via genuine termopen/jobstart(term
            -- = true) into a buffer named "[dap-terminal] <config.name>" --
            -- this is nvim-dap's own default (terminal_win_cmd = 'belowright
            -- new'), independent of dap-ui: dap-ui only overrides which
            -- window/buffer object gets reused for it
            -- (dap.defaults.fallback.terminal_win_cmd), the actual spawning
            -- and buffer naming happens in nvim-dap core either way. So
            -- watch for a genuine TermOpen on that name pattern -- no
            -- dependency on dap-ui being loaded, and (unlike easy-dotnet's
            -- own separate "term://" managed-terminal buffer, which stays
            -- unloaded until manually displayed) this is a real terminal
            -- channel, so nvim_buf_attach's on_lines fires reliably for it.
            --
            -- nvim-dap pools/reuses these terminal buffers across separate
            -- runInTerminal requests (session.lua terminals.acquire/release)
            -- and still calls termopen() again on a reused buffer -- which
            -- can refire TermOpen for the same bufnr. Dedup both the attach
            -- itself (attached_bufs) and the notified URLs (per-bufnr, not
            -- global) so a stray double-attach on one run can't double
            -- notify, while a genuinely new run (new bufnr) still notifies.
            local attached_bufs = {}

            local function watch_dap_terminal_for_listening_url(bufnr)
                if attached_bufs[bufnr] then return end
                attached_bufs[bufnr] = true
                local seen = {}
                local function scan(first, last)
                    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, first, last, false)) do
                        local url = line:match("Now listening on:%s*(%S+)")
                        if url and not seen[url] then
                            seen[url] = true
                            vim.notify("Listening on " .. url, vim.log.levels.INFO, { title = "dotnet" })
                        end
                    end
                end
                scan(0, -1)
                vim.api.nvim_buf_attach(bufnr, false, {
                    on_lines = function(_, _, _, first, last) scan(first, last) end,
                    on_detach = function() attached_bufs[bufnr] = nil end,
                })
            end

            -- The rename to "[dap-terminal] ..." happens right AFTER
            -- termopen() returns (session.lua run_in_terminal), which is
            -- after TermOpen has already fired -- so the name check has to
            -- be deferred a tick via vim.schedule, otherwise it always sees
            -- the buffer's still-default "term://..." name and never
            -- matches.
            vim.api.nvim_create_autocmd("TermOpen", {
                pattern = "*",
                desc = "Notify on ASP.NET Core Kestrel startup URLs",
                callback = function(args)
                    local bufnr = args.buf
                    vim.schedule(function()
                        if not vim.api.nvim_buf_is_valid(bufnr) then return end
                        if not vim.api.nvim_buf_get_name(bufnr):match("%[dap%-terminal%]") then return end
                        watch_dap_terminal_for_listening_url(bufnr)
                    end)
                end,
            })
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
            dap.listeners.before.event_terminated["dapui_config"] = function()
                dapui.close({})
            end
            dap.listeners.before.event_exited["dapui_config"] = function()
                dapui.close({})
            end
        end,
    }
}
