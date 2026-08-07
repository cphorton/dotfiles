-- Bridges nvim-dap's REPL omnifunc (dap.repl.omnifunc) into blink.cmp.
--
-- Why this exists: dap.repl.omnifunc implements Vim's classic *async*
-- omni-completion protocol (see `:h complete-functions`). For real
-- expression/member completions (e.g. `forecast[0].` -> TemperatureC,
-- TemperatureF, ...) it fires an async `completions` request to the debug
-- adapter and returns -2 from the findstart=1 call, meaning "stay in
-- completion mode, I'll call vim.fn.complete() myself once the adapter
-- responds". Blink's built-in "omni" source (blink.cmp.sources.complete_func)
-- does not implement that half of the protocol: on seeing -2 it just
-- resolves with no items and gives up. So only whatever completed
-- *synchronously* (REPL dot-commands like `.exit`) ever reached blink;
-- real member completions from the debug adapter never did, which is why
-- only bare variable names (via the `buffer` source echoing prior REPL
-- output) appeared to autocomplete.
--
-- This source stubs `vim.fn.complete` for the lifetime of the async
-- request so it can capture the items dap.repl would have inserted, then
-- forwards them into blink's own async `resolve` callback.

local Kind = require('blink.cmp.types').CompletionItemKind

local COMPLETE_ITEM_KIND_TO_BLINK_KIND = {
  v = Kind.Variable,
  f = Kind.Function,
  m = Kind.Field,
  t = Kind.TypeParameter,
  d = Kind.Constant,
}

local function item_to_blink(cmp, range)
  if type(cmp) == 'string' then
    return {
      label = cmp,
      textEdit = { range = range, newText = cmp },
    }
  end

  local item = {
    label = cmp.abbr or cmp.word,
    textEdit = { range = range, newText = cmp.word },
    labelDetails = { description = cmp.menu },
  }

  local blink_kind = COMPLETE_ITEM_KIND_TO_BLINK_KIND[cmp.kind]
  if blink_kind ~= nil then
    item.kind = blink_kind
  else
    item.labelDetails.detail = cmp.kind
  end

  if cmp.info ~= nil and #cmp.info > 0 then
    item.documentation = { value = cmp.info, kind = 'plaintext' }
  end

  return item
end

-- Captured once at load time so overlapping requests always restore the
-- *true* underlying implementation, never a still-installed stub from a
-- previous in-flight request.
local real_vim_fn_complete = vim.fn.complete

local generation = 0

---@class DapReplSource : blink.cmp.Source
local Source = {}

function Source.new()
  return setmetatable({}, { __index = Source })
end

-- Any buffer that wants dap.repl's expression/member completion (the
-- REPL itself, and dap_quickwatch's expression input box) lists its
-- filetype here.
local ENABLED_FILETYPES = {
  ['dap-repl'] = true,
  ['dap-quickwatch-input'] = true,
}

function Source:enabled()
  return ENABLED_FILETYPES[vim.bo.filetype] == true
end

function Source:get_trigger_characters()
  return { '.', '[' }
end

function Source:get_completions(context, resolve)
  local ok, dap_repl = pcall(require, 'dap.repl')
  if not ok then
    resolve()
    return
  end

  generation = generation + 1
  local my_generation = generation

  local cur_line, cur_col = unpack(context.cursor)

  local function finish(items, start_col)
    if my_generation ~= generation then
      -- A newer request superseded this one; don't resolve with stale items.
      return
    end
    -- netcoredbg's `completions` request sometimes answers with
    -- indexer-shaped suggestions ("[0]", "[1]", ...) even when completing
    -- after a literal "." rather than "[" -- observed for array-typed root
    -- expressions (e.g. `forecast.` where `forecast` is a `T[]`), which
    -- apparently don't have a real dot-member list to offer and fall back
    -- to this instead. Those can never be syntactically valid right after
    -- a dot, so drop them rather than show completions that don't parse.
    local trigger_char = context.line:sub(start_col, start_col)
    if trigger_char == '.' then
      items = vim.tbl_filter(function(cmp)
        local text = type(cmp) == 'string' and cmp or cmp.word
        return text == nil or not text:match('^%[%-?%d+%]$')
      end, items)
    end
    local range = {
      ['start'] = { line = cur_line - 1, character = start_col },
      ['end'] = { line = cur_line - 1, character = cur_col },
    }
    local blink_items = {}
    for _, cmp in ipairs(items) do
      table.insert(blink_items, item_to_blink(cmp, range))
    end
    resolve({ is_incomplete_forward = false, is_incomplete_backward = false, items = blink_items })
  end

  local restored = false
  local function restore()
    if not restored then
      restored = true
      vim.fn.complete = real_vim_fn_complete
    end
  end

  -- Intercepts the eventual `vim.fn.complete(startcol, matches)` call that
  -- dap.repl's async `completions` response handler makes.
  vim.fn.complete = function(startcol, matches)
    restore()
    finish(matches, startcol - 1)
  end

  local ok_start, start_col = pcall(dap_repl.omnifunc, 1, '')

  if not ok_start or type(start_col) ~= 'number' then
    restore()
    resolve()
    return
  end

  if start_col == -2 or start_col == -3 then
    -- Async path: the request was already dispatched by the call above;
    -- the `vim.fn.complete` stub will call `finish()` once the debug
    -- adapter responds. Safety net in case it never does (e.g. session
    -- died mid-request), so we don't leave `vim.fn.complete` stubbed out
    -- forever.
    vim.defer_fn(function()
      if not restored then
        restore()
        resolve()
      end
    end, 3000)
    return
  end

  -- Synchronous path (e.g. REPL dot-commands): omnifunc already returned
  -- the real start column, so call it again with findstart=0 for items.
  restore()

  if start_col < 0 or start_col > cur_col then
    resolve()
    return
  end

  local base = string.sub(context.line, start_col + 1, cur_col)
  local ok_items, items = pcall(dap_repl.omnifunc, 0, base)
  if not ok_items or type(items) ~= 'table' then
    resolve()
    return
  end

  finish(items, start_col)
end

return Source
