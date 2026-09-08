return {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = function(_, opts)
        -- The picker's file previewer reads not-yet-open files with raw
        -- io.open():lines(), which only splits on "\n" -- a CRLF file keeps the
        -- trailing "\r" attached to every line (rendered as a literal ^M) and a
        -- leading UTF-8 BOM shows up as literal <feff>, neither of which Neovim's
        -- normal :edit path would show (fileformat/BOM are auto-detected there).
        -- Patch the one choke point all previewers funnel lines through --
        -- Preview:set_lines -- to strip both before they hit the preview buffer.
        local Preview = require("snacks.picker.core.preview")
        local set_lines = Preview.set_lines

        local function set_picker_file(picker, item)
            vim.schedule(function()
                vim.g.snacks_picker_file = item and item.file or nil
                picker.preview.win:set_title(item.file)
            end)
        end
        local vertical_layout = { preset = "vertical" }
        local snacks_layout_is_horizontal = true


        local horizontal_layout = {
            layout = {
                box = "horizontal",
                width = 0.8,
                height = 0.8,
                backdrop = false,
                {
                    box = "vertical",
                    width = 0.35,
                    border = "rounded",
                    title = "{source} {live}",
                    title_pos = "center",
                    { win = "input", height = 1,     border = "bottom" },
                    { win = "list",  border = "none" },
                },
                {
                    win = "preview",
                    border = "rounded",
                    width = 0.65,
                },
            },
        }

        local vertical_layout = {
            layout = {
                box = "vertical",
                width = 0.8,
                height = 0.8,
                backdrop = false,
                {
                    box = "vertical",
                    height = 0.35,
                    border = "rounded",
                    title = "{source} {live}",
                    title_pos = "center",
                    { win = "input", height = 1,     border = "bottom" },
                    { win = "list",  border = "none" },
                },
                {
                    win = "preview",
                    border = "rounded",
                    height = 0.65,
                },
            },
        }



        Preview.set_lines = function(self, lines, offset)
            for i, line in ipairs(lines) do
                lines[i] = line:gsub("\r$", "")
            end
            if lines[1] then
                lines[1] = lines[1]:gsub("^\239\187\191", "")
            end
            return set_lines(self, lines, offset)
        end

        return vim.tbl_deep_extend("force", opts, {
            picker = {
                layouts = {
                    horizontal = { preset = "default" }, -- your current default (list+preview side by side)
                    vertical = { preset = "vertical" },  -- built-in vertical preset
                },
                win = {
                    input = {
                        keys = {
                            ["<Tab>"] = { "focus_preview", mode = { "i", "n" } },
                            ["<a-v>"] = { "toggle_layout_orientation", mode = { "i", "n" } },
                        },
                    },
                    preview = {
                        wo = {
                            wrap = false,
                        },
                        keys = {
                            ["<Tab>"] = "focus_input",
                        },
                    },
                },
                layout = horizontal_layout,
                actions = {
                    toggle_layout_orientation = function(picker)
                        snacks_layout_is_horizontal = not snacks_layout_is_horizontal
                        picker:set_layout(snacks_layout_is_horizontal and horizontal_layout or vertical_layout)
                    end,
                },
                sources = {
                    files = { on_change = set_picker_file },
                    smart = { on_change = set_picker_file },
                    grep = { on_change = set_picker_file },
                    buffers = { on_change = set_picker_file },
                    recent = { on_change = set_picker_file },
                },
            },
            explorer = {},
            dashboard = { enabled = true },
            toggle = { enabled = true },
        })
    end,
    keys = {
        -- Top Pickers & Explorer
        { "<leader>fs",       function() Snacks.picker.smart() end,                                   desc = "Smart Find Files" },
        { "<leader>,",        function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
        { "<leader>/",        function() Snacks.picker.grep() end,                                    desc = "Grep" },
        { "<leader>:",        function() Snacks.picker.command_history() end,                         desc = "Command History" },
        { "<leader>n",        function() Snacks.picker.notifications() end,                           desc = "Notification History" },
        { "<leader>e",        function() Snacks.explorer() end,                                       desc = "File Explorer" },
        -- find
        { "<leader>fb",       function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
        { "<leader>fc",       function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
        { "<leader><leader>", function() Snacks.picker.files() end,                                   desc = "Find Files" },
        { "<leader>fg",       function() Snacks.picker.git_files() end,                               desc = "Find Git Files" },
        { "<leader>fp",       function() Snacks.picker.projects() end,                                desc = "Projects" },
        { "<leader>fr",       function() Snacks.picker.recent() end,                                  desc = "Recent" },
        { "<leader>fd",       function() Snacks.picker.diagnostics() end,                             desc = "Diagnostics" },
        -- git
        { "<leader>gb",       function() Snacks.picker.git_branches() end,                            desc = "Git Branches" },
        { "<leader>gl",       function() Snacks.picker.git_log() end,                                 desc = "Git Log" },
        { "<leader>gL",       function() Snacks.picker.git_log_line() end,                            desc = "Git Log Line" },
        { "<leader>gs",       function() Snacks.picker.git_status() end,                              desc = "Git Status" },
        { "<leader>gS",       function() Snacks.picker.git_stash() end,                               desc = "Git Stash" },
        { "<leader>gd",       function() Snacks.picker.git_diff() end,                                desc = "Git Diff (Hunks)" },
        { "<leader>gf",       function() Snacks.picker.git_log_file() end,                            desc = "Git Log File" },
        -- Grep
        { "<leader>sb",       function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
        { "<leader>sB",       function() Snacks.picker.grep_buffers() end,                            desc = "Grep Open Buffers" },
        { "<leader>sg",       function() Snacks.picker.grep() end,                                    desc = "Grep" },
        { "<leader>sw",       function() Snacks.picker.grep_word() end,                               desc = "Visual selection or word", mode = { "n", "x" } },
        -- search
        { '<leader>s"',       function() Snacks.picker.registers() end,                               desc = "Registers" },
        { '<leader>s/',       function() Snacks.picker.search_history() end,                          desc = "Search History" },
        { "<leader>sa",       function() Snacks.picker.autocmds() end,                                desc = "Autocmds" },
        { "<leader>sb",       function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
        { "<leader>sc",       function() Snacks.picker.command_history() end,                         desc = "Command History" },
        { "<leader>sC",       function() Snacks.picker.commands() end,                                desc = "Commands" },
        { "<leader>sd",       function() Snacks.picker.diagnostics() end,                             desc = "Diagnostics" },
        { "<leader>sD",       function() Snacks.picker.diagnostics_buffer() end,                      desc = "Buffer Diagnostics" },
        { "<leader>sh",       function() Snacks.picker.help() end,                                    desc = "Help Pages" },
        { "<leader>sH",       function() Snacks.picker.highlights() end,                              desc = "Highlights" },
        { "<leader>si",       function() Snacks.picker.icons() end,                                   desc = "Icons" },
        { "<leader>sj",       function() Snacks.picker.jumps() end,                                   desc = "Jumps" },
        { "<leader>sk",       function() Snacks.picker.keymaps() end,                                 desc = "Keymaps" },
        { "<leader>sl",       function() Snacks.picker.loclist() end,                                 desc = "Location List" },
        { "<leader>sm",       function() Snacks.picker.marks() end,                                   desc = "Marks" },
        { "<leader>sM",       function() Snacks.picker.man() end,                                     desc = "Man Pages" },
        { "<leader>sp",       function() Snacks.picker.lazy() end,                                    desc = "Search for Plugin Spec" },
        { "<leader>sq",       function() Snacks.picker.qflist() end,                                  desc = "Quickfix List" },
        { "<leader>sR",       function() Snacks.picker.resume() end,                                  desc = "Resume" },
        { "<leader>su",       function() Snacks.picker.undo() end,                                    desc = "Undo History" },
        { "<leader>uC",       function() Snacks.picker.colorschemes() end,                            desc = "Colorschemes" },
        -- LSP
        { "gd",               function() Snacks.picker.lsp_definitions() end,                         desc = "Goto Definition" },
        { "gD",               function() Snacks.picker.lsp_declarations() end,                        desc = "Goto Declaration" },
        { "gr",               function() Snacks.picker.lsp_references() end,                          nowait = true,                     desc = "References" },
        { "gI",               function() Snacks.picker.lsp_implementations() end,                     desc = "Goto Implementation" },
        { "gy",               function() Snacks.picker.lsp_type_definitions() end,                    desc = "Goto T[y]pe Definition" },
        { "<leader>ss",       function() Snacks.picker.lsp_symbols() end,                             desc = "LSP Symbols" },
        { "<leader>sS",       function() Snacks.picker.lsp_workspace_symbols() end,                   desc = "LSP Workspace Symbols" },
    },
}
