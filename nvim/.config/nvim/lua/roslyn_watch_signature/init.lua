-- Real Roslyn signature help (parameter hints, including overload
-- cycling) for the QuickWatch expression box.
--
-- Same trick as roslyn_watch_completion (see that module's own comment
-- for the full rationale): temporarily insert the expression as a bare
-- line right after the current stack frame's source line in the real
-- .cs buffer, ask Roslyn for signature help there, then revert. The
-- attached Roslyn LSP client only exists on that buffer, not the
-- QuickWatch scratch buffer, and only it knows about overload resolution
-- for a call like `forecast.Where(` -- a debug adapter has no equivalent
-- (same reason roslyn_watch_completion exists rather than relying on
-- dap_repl_completion for member completions).
--
-- Deliberately not built on blink.cmp's own signature help (disabled
-- project-wide, see blink.lua -- upstream can't cycle overloads) or on
-- Issafalcon/lsp-overloads.nvim (see lsp-overloads.lua -- it resolves
-- signature help against whatever LSP client is attached to the
-- *current* buffer, which for the QuickWatch scratch buffer is none).
-- This is a small, self-contained popup instead, reusing Neovim's own
-- vim.lsp.util helpers for formatting/rendering rather than hand-rolling
-- either.

local M = {}

---@type table
local state = {} -- { win, buf, signature_help, active_index }
local generation = 0

-- Tracks an in-flight transient edit so a fast-typing burst can't leave
-- two overlapping inserts in the .cs buffer -- see
-- roslyn_watch_completion's identical pending/revert_pending pair.
local pending = nil

local function revert_pending()
  if not pending then
    return
  end
  local buf, row = pending.bufnr, pending.row
  pending = nil
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_set_lines, buf, row, row + 1, false, {})
  end
end

function M.hide()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state = {}
end

function M.is_visible()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- signature_help/active_index kept in `state` (not re-fetched) so
-- M.cycle() can re-render without another LSP round trip.
local function render(signature_help, active_index)
  local render_help = vim.deepcopy(signature_help)
  render_help.activeSignature = active_index

  local lines, hl_range = vim.lsp.util.convert_signature_help_to_markdown_lines(render_help, 'cs', { '(', ',' })
  if not lines or #lines == 0 then
    M.hide()
    return
  end

  local count = #signature_help.signatures
  if count > 1 then
    table.insert(lines, 1, ('(%d/%d) <C-k> for next overload'):format(active_index + 1, count))
    table.insert(lines, 2, '')
    if hl_range then
      hl_range[1] = hl_range[1] + 2
      hl_range[3] = hl_range[3] + 2
    end
  end

  M.hide() -- close any previous popup before opening the replacement

  -- Deliberately NOT vim.lsp.util.open_floating_preview: its automatic
  -- above/below sizing (make_floating_popup_options) derives "space
  -- above/below the cursor" from the *current window's own*
  -- winline()/winheight() -- for a 1-line QuickWatch input float that's
  -- always ~0/1 regardless of where that float actually sits on screen,
  -- so it collapses the popup to height 0 no matter which anchor_bias is
  -- requested (confirmed empirically -- not a hypothetical). Hand-rolling
  -- a plain relative='cursor' float sidesteps that heuristic entirely: a
  -- fixed "always above" offset is exactly what was wanted anyway
  -- (matches lsp-overloads.nvim's floating_window_above_cur_line
  -- convention for real .cs files), and doesn't depend on any window's
  -- reported height.
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(width, math.max(vim.o.columns - 4, 20))
  local height = math.min(#lines, 15)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = 'markdown'

  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'cursor',
    anchor = 'SW', -- bottom-left corner at the cursor -- extends upward
    row = 0,
    col = 0,
    width = width,
    height = height,
    border = 'rounded',
    style = 'minimal',
    focusable = false,
    zindex = 200,
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  pcall(vim.treesitter.start, buf, 'markdown')

  if hl_range then
    vim.api.nvim_buf_add_highlight(buf, -1, 'LspSignatureActiveParameter', hl_range[1], hl_range[2], hl_range[4])
  end
  state = { win = win, buf = buf, signature_help = signature_help, active_index = active_index }
end

-- Cycles to the next overload of the currently-displayed signature help
-- (wrapping) without a new LSP round trip. A no-op if nothing is shown or
-- there's only one overload.
function M.cycle()
  if not state.signature_help then
    return
  end
  local count = #state.signature_help.signatures
  if count <= 1 then
    return
  end
  render(state.signature_help, (state.active_index + 1) % count)
end

-- Reads the calling window's cursor/line directly rather than taking
-- them as arguments: always called synchronously from a keymap/autocmd
-- on the QuickWatch input buffer, so "the current window" at call time
-- is unambiguous, unlike roslyn_watch_completion's context.line/cursor
-- params (that one's driven by blink.cmp's own async completion engine,
-- which passes its own captured context rather than "current" anything).
function M.trigger()
  revert_pending()

  local win = vim.api.nvim_get_current_win()
  local cursor_col = vim.api.nvim_win_get_cursor(win)[2]
  local expr = vim.api.nvim_get_current_line()

  local dap_ok, dap = pcall(require, 'dap')
  local session = dap_ok and dap.session()
  local frame = session and session.current_frame
  if not frame or not frame.source or not frame.source.path then
    return
  end

  local ok_bufnr, bufnr = pcall(vim.uri_to_bufnr, vim.uri_from_fname(frame.source.path))
  if not ok_bufnr or not bufnr then
    return
  end
  local ok_load = pcall(vim.fn.bufload, bufnr)
  if not ok_load or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local clients = vim.tbl_filter(
    function(client) return client.server_capabilities and client.server_capabilities.signatureHelpProvider end,
    vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/signatureHelp' })
  )
  if #clients == 0 then
    return
  end

  -- frame.line is 1-indexed (DAP default); nvim_buf_set_lines(buf, N, N, ...)
  -- inserts right after 1-indexed line N when given 0-indexed row N -- no
  -- adjustment needed. Matches roslyn_watch_completion's identical logic.
  local insert_row = frame.line
  local ok_insert = pcall(vim.api.nvim_buf_set_lines, bufnr, insert_row, insert_row, false, { expr })
  if not ok_insert then
    return
  end
  pending = { bufnr = bufnr, row = insert_row }

  local params = {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = insert_row, character = cursor_col },
  }

  generation = generation + 1
  local my_generation = generation

  local remaining = #clients
  local best = nil

  for _, client in ipairs(clients) do
    client:request('textDocument/signatureHelp', params, function(err, result)
      remaining = remaining - 1
      if not err and result and result.signatures and #result.signatures > 0 then
        best = result
      end
      if remaining <= 0 then
        revert_pending()
        if generation ~= my_generation then
          return -- superseded by a newer trigger() call
        end
        if not (win and vim.api.nvim_win_is_valid(win)) then
          return -- QuickWatch closed while this was in flight
        end
        if best then
          render(best, best.activeSignature or 0)
        else
          M.hide()
        end
      end
    end, bufnr)
  end
end

return M
