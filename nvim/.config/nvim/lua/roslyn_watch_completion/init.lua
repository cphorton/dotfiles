-- Prototype: real Roslyn completions for the QuickWatch expression box.
--
-- Why this exists: dap_repl_completion (the debug-adapter-based source)
-- can only ever offer reflection-based completions -- it has no way to
-- know about extension methods (LINQ's Where/Select/First/...), since
-- that requires compile-time knowledge of `using` directives and overload
-- resolution, not runtime type inspection. The easy_dotnet Roslyn LSP
-- client is already attached to the .cs buffer at the breakpoint and knows
-- all of that.
--
-- Approach: temporarily insert the QuickWatch expression as a bare line
-- immediately after the current stack frame's source line, in that (often
-- not visible/current) .cs buffer, ask Roslyn for completions at the end
-- of that line, then revert the insert. C# scoping is brace-based, not
-- indentation-based, so a zero-indent line inserted at the right point in
-- the token stream sees exactly the locals in scope at the breakpoint.
-- The edit never touches disk (in-memory buffer only) and is reverted
-- before this function resolves.

local Source = {}

function Source.new()
  return setmetatable({}, { __index = Source })
end

function Source:enabled()
  return vim.bo.filetype == 'dap-quickwatch-input'
end

function Source:get_trigger_characters()
  return { '.', '[' }
end

-- Tracks an in-flight transient edit so a fast-typing burst can't leave
-- two overlapping inserts in the .cs buffer; the next call reverts
-- whatever the previous one left behind before doing its own insert.
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

local CompletionTriggerKind = vim.lsp.protocol.CompletionTriggerKind

function Source:get_completions(context, resolve)
  revert_pending()

  local dap_ok, dap = pcall(require, 'dap')
  local session = dap_ok and dap.session()
  local frame = session and session.current_frame
  if not frame or not frame.source or not frame.source.path then
    resolve()
    return
  end

  local ok_bufnr, bufnr = pcall(vim.uri_to_bufnr, vim.uri_from_fname(frame.source.path))
  if not ok_bufnr or not bufnr then
    resolve()
    return
  end
  local ok_load = pcall(vim.fn.bufload, bufnr)
  if not ok_load or not vim.api.nvim_buf_is_loaded(bufnr) then
    resolve()
    return
  end

  local clients = vim.tbl_filter(
    function(client) return client.server_capabilities and client.server_capabilities.completionProvider end,
    vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/completion' })
  )
  if #clients == 0 then
    resolve()
    return
  end

  -- frame.line is 1-indexed (DAP default); nvim_buf_set_lines(buf, N, N, ...)
  -- inserts right after 1-indexed line N when given 0-indexed row N -- no
  -- adjustment needed.
  local insert_row = frame.line
  local expr = context.line

  local ok_insert = pcall(vim.api.nvim_buf_set_lines, bufnr, insert_row, insert_row, false, { expr })
  if not ok_insert then
    resolve()
    return
  end
  pending = { bufnr = bufnr, row = insert_row }

  local params = {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = insert_row, character = #expr },
    context = {
      triggerKind = context.trigger.kind == 'trigger_character' and CompletionTriggerKind.TriggerCharacter
        or CompletionTriggerKind.Invoked,
    },
  }
  if context.trigger.kind == 'trigger_character' then
    params.context.triggerCharacter = context.trigger.character
  end

  -- Remaps a range that was resolved against the temp line in the .cs
  -- buffer (line = insert_row) back into the QuickWatch buffer's single
  -- line (line = 0). Character offsets transfer as-is: the temp line's
  -- text is byte-for-byte identical to the QuickWatch line (no indent
  -- prefix was added).
  local function remap_range(range)
    if not range then
      return range
    end
    range.start.line = 0
    range["end"].line = 0
    return range
  end

  local remaining = #clients
  local items = {}
  local is_incomplete_forward = false
  local finished = false

  local function finish()
    if finished then
      return
    end
    finished = true
    revert_pending()
    resolve({
      is_incomplete_forward = is_incomplete_forward,
      is_incomplete_backward = true,
      items = items,
    })
  end

  for _, client in ipairs(clients) do
    client:request('textDocument/completion', params, function(err, result)
      remaining = remaining - 1
      if not err and result then
        local raw_items = result.items or result
        local default_edit_range = result.itemDefaults and result.itemDefaults.editRange
        is_incomplete_forward = is_incomplete_forward or (result.isIncomplete or false)

        for _, item in ipairs(raw_items) do
          item.client_id = client.id
          item.client_name = client.name
          item.cursor_column = context.cursor[2]

          if item.textEdit then
            remap_range(item.textEdit.range or item.textEdit.replace)
            remap_range(item.textEdit.insert)
          elseif default_edit_range then
            local new_text = item.textEditText or item.insertText or item.label
            if default_edit_range.replace ~= nil then
              item.textEdit = {
                replace = remap_range(vim.deepcopy(default_edit_range.replace)),
                insert = remap_range(vim.deepcopy(default_edit_range.insert)),
                newText = new_text,
              }
            else
              item.textEdit = {
                range = remap_range(vim.deepcopy(default_edit_range)),
                newText = new_text,
              }
            end
          end

          table.insert(items, item)
        end
      end

      if remaining <= 0 then
        finish()
      end
    end, bufnr)
  end
end

return Source
