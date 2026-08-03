return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
        "MunifTanjim/nui.nvim",
        -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    opts = function(_, opts)
        -- neo-tree's gitignore matcher crashes the whole tree render if a file's
        -- name, once its backslashes are normalized to forward slashes for pattern
        -- matching, produces a path segment that doesn't correspond to any real
        -- directory on disk (e.g. a stray file literally named "c:\Logs\foo.log").
        -- ignored.lua's type() callback does assert(uv.fs_stat(path)).type with no
        -- handling for a nonexistent path. That closure is anonymous/unreachable
        -- from outside, so wrap the nearest exported entry point instead: mark_ignored
        -- mutates its `items` list in place and has no meaningful return value, so
        -- pcall-wrapping it is safe -- on failure, whatever wasn't processed yet in
        -- that batch just won't get ignore-status applied (a stray file that should've
        -- been hidden shows up in the tree instead) rather than crashing neo-tree.
        -- Guarded for the function's existence so a future neo-tree update that
        -- renames/restructures this just silently no-ops instead of erroring.
        local ok, ignored = pcall(require, "neo-tree.sources.filesystem.lib.ignored")
        if ok and type(ignored.mark_ignored) == "function" then
            local original_mark_ignored = ignored.mark_ignored
            ignored.mark_ignored = function(state, items)
                local call_ok, err = pcall(original_mark_ignored, state, items)
                if not call_ok then
                    vim.notify(
                        "[neo-tree] gitignore check failed on an unusually-named file: " .. tostring(err),
                        vim.log.levels.WARN
                    )
                end
            end
        end

        local function on_move(data)
            Snacks.rename.on_rename_file(data.source, data.destination)
        end
        local events = require("neo-tree.events")
        opts.event_handlers = opts.event_handlers or {}
        vim.list_extend(opts.event_handlers, {
            { event = events.FILE_MOVED,   handler = on_move },
            { event = events.FILE_RENAMED, handler = on_move },
        })



        return {
            enable_diagnostics = true,
            sources = { "filesystem", "buffers", "git_status", "neotree_dotnet" },
            default_component_configs = {
                git_status = {
                    symbols = {
                        added = "",
                        modified = "",
                        deleted = "",
                        renamed = "",
                        untracked = "",
                        ignored = "",
                        unstaged = "",
                        staged = "",
                        conflict = "",
                    },
                },
            },
            window = {
                mappings = {
                    ['v'] = "expand_all_nodes",
                    ['e'] = function() vim.api.nvim_exec('Neotree focus filesystem float', true) end,
                    ['b'] = function() vim.api.nvim_exec('Neotree focus buffers float', true) end,
                    ['g'] = function() vim.api.nvim_exec('Neotree focus git_status float', true) end,
                    ['d'] = function() vim.api.nvim_exec('Neotree focus dotnet float', true) end,
                    ['p'] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
                }
            },
            -- Overrides just the dotnet source's own window mappings; 'a'/'d' still
            -- mean "add file"/"delete file" everywhere else (filesystem/buffers/git_status).
            -- 'p' deliberately isn't overridden here -- the global toggle_preview
            -- mapping above already reaches package-aware previewing, since
            -- neotree_dotnet.commands patches neo-tree's own Preview.show (not
            -- just the toggle_preview command) to special-case package nodes.
            -- See that patch's doc comment for why it has to be Preview.show
            -- specifically: neo-tree's cursor-moved auto-refresh calls that
            -- directly, bypassing whatever's bound to 'p' entirely.
            dotnet = {
                window = {
                    mappings = {
                        ['a'] = "add_nuget_package",
                        ['d'] = "remove_nuget_package",
                    }
                }
            }
        }
    end,
    keys = {
        { "<leader>ft", "<cmd>Neotree float reveal<cr>", desc = "Neotree Popup reveal" },
        { "<leader>fD", "<cmd>Neotree float dotnet<cr>", desc = "Dotnet Solution Explorer" },
    }
}
