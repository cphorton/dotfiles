-- kmiterror/dotnet-debug.nvim: debugger-agnostic DAP wiring for .NET, used
-- here to test alternatives to easy-dotnet.nvim's built-in debugging.
-- Registers a "coreclr" adapter (for .vscode/launch.json-based sessions),
-- distinct from easy-dotnet.nvim's own "easy-dotnet" adapter (see
-- easy-dotnet.lua, debugger.auto_register_dap = true) -- different adapter
-- names, no collision even with both registered.
--
-- Points debugger_path at our own build of dncdbg (github.com/cphorton/dncdbg,
-- a netcoredbg fork) at ~/Development/dncdbg, currently on
-- dev/combined-array-fixes -- fixes two real netcoredbg bugs that broke
-- dap_quickwatch on array-typed expressions: `array.Length`/`array.Rank`
-- never resolving, and any method call on an array (including every LINQ
-- method) hanging/failing outright. See that repo's git log for details.
--
-- NOTE: dotnet-debug.nvim's setup() calls dapui.setup() with its own layout,
-- which can clobber the dapui.setup() in dap.lua depending on plugin load
-- order -- worth watching for if the DAP UI layout looks different than
-- expected.
--
-- NOTE: to actually run a debug session, drop a .vscode/launch.json (type
-- "coreclr") into the target project -- nvim-dap loads it on-demand, this
-- plugin doesn't read it itself. See the plugin README for an example.
return {
    "kmiterror/dotnet-debug.nvim",
    dependencies = { "mfussenegger/nvim-dap", "rcarriga/nvim-dap-ui" },
    config = function()
        local debugger_path = vim.fn.expand("~/Development/dncdbg/bin/dncdbg")
        if vim.fn.filereadable(debugger_path) == 0 then
            vim.notify(
                "dotnet-debug.nvim: dncdbg binary not found at " .. debugger_path .. ". Has it been built?",
                vim.log.levels.ERROR
            )
            return
        end

        require("dotnet-debug").setup({
            debugger_path = debugger_path,
        })
    end,
}
