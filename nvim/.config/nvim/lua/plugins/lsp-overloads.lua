return {
    "Issafalcon/lsp-overloads.nvim",
    event = "InsertEnter",
    opts = {
        ui = {
            -- avoid drawing under blink.cmp's completion menu, same reasoning as the
            -- lsp_signature.nvim setup this replaced
            floating_window_above_cur_line = true,
            -- Default close_events = { "CursorMoved", "BufHidden", "InsertLeave" }.
            -- CursorMoved is the *normal-mode* autocommand -- it never fires while
            -- still typing in insert mode, so finishing a call and continuing to type
            -- more code left the popup stuck open until InsertLeave. Add CursorMovedI
            -- (the insert-mode equivalent) so it actually closes as you move on.
            close_events = { "CursorMoved", "CursorMovedI", "BufHidden", "InsertLeave" },
        },
        -- keymaps.next_signature/previous_signature default to <C-j>/<C-k> already --
        -- cycles overloads both directions, unlike the old single-direction <C-j> only.
    },
    config = function(_, opts)
        require("lsp-overloads").setup(opts)
    end,
}
