return -- lazy.nvim
{
    "GustavEikaas/easy-dotnet.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim" },
    config = function()
        require("easy-dotnet").setup({
            lsp = {
                auto_refresh_codelens = true,
            },
            debugger = {
                auto_register_dap = true,
            },
        })

        vim.api.nvim_set_hl(0, "LspCodeLens", { fg = "#717171", italic = true })

        vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*.cs",
            callback = function(args)
                vim.lsp.buf.format({ bufnr = args.buf, async = false })
            end,
            desc = "Format C# buffers via Roslyn LSP on save",
        })

        -- easy-dotnet's on_attach sets indentexpr to Neovim's bundled legacy
        -- GetCSIndent() (indent/cs.vim), which just delegates to Vim's classic
        -- cindent() for ordinary lines. cindent() loses track of an inner unmatched
        -- "{" when it's nested inside an also-unmatched outer "(" -- e.g. a lambda
        -- block passed mid-expression in a fluent call chain:
        --   services.AddApiVersioning(options =>
        --   {
        --       <-- pressing 'o' here indents to match "services." instead of one
        --           level past the "{", because cindent's brace search gets
        --           confused by the still-open outer paren. No cinoptions setting
        --           changes this -- confirmed by testing every relevant flag.
        -- Layer a small, targeted override in front of it instead of replacing the
        -- whole engine (nvim-treesitter has no c_sharp indents.scm to fall back to
        -- anyway): if the previous line simply ends in "{", indent one shiftwidth
        -- past it -- unless the line being indented itself starts with a closer
        -- (}, ), ]), in which case defer to GetCSIndent, which already handles
        -- closing-brace dedent correctly.
        _G.CSharpSmartIndent = function(lnum)
            local this_line = vim.fn.getline(lnum):gsub("^%s+", "")
            local starts_with_closer = this_line:match("^[%}%)%]]") ~= nil
            if not starts_with_closer then
                local prevlnum = vim.fn.prevnonblank(lnum - 1)
                if prevlnum > 0 then
                    local prevline = vim.fn.getline(prevlnum):gsub("%s+$", "")
                    if prevline:sub(-1) == "{" then
                        return vim.fn.indent(prevlnum) + vim.fn.shiftwidth()
                    end
                end
            end
            return vim.fn.GetCSIndent(lnum)
        end

        -- Neovim core fires LspAttach *before* running the client's raw on_attach
        -- callbacks (see vim/lsp/client.lua Client:on_attach: nvim_exec_autocmds
        -- ('LspAttach', ...) happens, THEN self:_run_callbacks(self._on_attach_cbs,
        -- ...) -- the opposite of what you'd guess). easy-dotnet's on_attach is what
        -- calls fix_indent_expression(), so a plain LspAttach handler here would run
        -- and then immediately get overwritten by easy-dotnet's own callback right
        -- after. There are also two clients attaching per .cs buffer (easy_dotnet_
        -- in_process and easy_dotnet), each re-running that reset. vim.schedule()
        -- defers this to the next event-loop tick, guaranteed after both clients'
        -- synchronous on_attach callbacks have already finished.
        vim.api.nvim_create_autocmd("LspAttach", {
            desc = "Layer CSharpSmartIndent on top of easy-dotnet's indentexpr for .cs buffers",
            callback = function(args)
                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(args.buf) and vim.bo[args.buf].filetype == "cs" then
                        vim.bo[args.buf].indentexpr = "v:lua.CSharpSmartIndent(v:lnum)"
                    end
                end)
            end,
        })
    end
}
