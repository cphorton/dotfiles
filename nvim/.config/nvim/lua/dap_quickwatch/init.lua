-- Visual Studio QuickWatch equivalent: a floating window with an editable
-- expression box (top) and an expandable Name/Value/Type tree (bottom),
-- for one-off ad hoc evaluation against the live debug session -- distinct
-- from the transient dap-repl and the persistent dapui Watches sidebar.
--
-- Two floating windows rather than one split buffer: dap.ui's tree
-- renderer (see below) expects its target buffer to stay
-- modifiable=false between renders, which conflicts with a freely
-- editable expression line living in the same buffer.
--
-- Built on nvim-dap's own generic tree engine (dap.ui.new_tree +
-- dap.entity.variable.tree_spec) instead of reimplementing
-- variablesReference-driven lazy expansion -- that spec already handles
-- both raw `evaluate` responses (root, no `.name`) and `dap.Variable`
-- children (`.name` present). Only the rendering functions are
-- overridden, to get fixed-width Name/Value/Type columns instead of the
-- default single "name: value" line.
local ui = require('dap.ui')
local entity = require('dap.entity')
local signature = require('roslyn_watch_signature')

local M = {}

local COL_NAME, COL_VALUE = 32, 44

---@type table
local state = {}

-- Fallback cap for the Type column when state.tree_width isn't available
-- (shouldn't happen in real usage -- M.open() always sets it -- just a
-- safety net).
local FALLBACK_COL_TYPE = 40
local MIN_COL_TYPE = 8

-- dap.ui's own renderer (dap/ui.lua's Layer.render) only ever calls
-- render_fn(item) -- no context, no indent -- so render_row can't be
-- TOLD how deeply nested the row it's rendering is; indent is prepended
-- entirely *after* render_row returns, by dap.ui's own with_indent
-- wrapper (+2 cells per nesting level). A first attempt used one fixed
-- margin (24 cells) subtracted from every row's cap regardless of actual
-- depth -- that avoided hard-clipping, but blanket-truncated *every*
-- row's type, including the root row (indent=0, no margin needed at
-- all), confirmed live by inspecting the actual rendered buffer over
-- nvim's own RPC (`nvim --server <addr> --remote-expr`) on the running
-- session -- every row *did* get a graceful '…' with that fix, just a
-- needlessly aggressive one for shallow rows.
--
-- dap.ui does track each row's ancestry, just not for this purpose: in
-- expand() (dap/ui.lua), any child that itself has_children gets
-- `child.__parent = {key=<parent key>, __parent=<parent's own __parent>}`
-- -- a linked list back to the root, built specifically for dap.ui's own
-- expand-state lookups (is_expanded/set_expanded). Walking it gives the
-- exact hop count to the root, and each hop is exactly one +2 indent
-- level (verified by tracing expand()'s indent arithmetic by hand and
-- confirming against the live 3-levels-deep case). Only set on
-- expandable (has_children) rows, so it's nil for leaves regardless of
-- their real depth -- but leaf types are always short CLR primitives
-- (int, bool, string...), so a small flat floor for that case is safe.
local LEAF_INDENT_MARGIN = 6

local function estimate_indent(var)
  local hops = 0
  local p = var.__parent
  while p do
    hops = hops + 1
    p = p.__parent
  end
  if hops == 0 then
    return LEAF_INDENT_MARGIN
  end
  return hops * 2
end

-- Type is the last column, so nothing to its right needs it padded out to
-- a fixed width -- but it does need a *cap*, sized to whatever room is
-- actually left in the tree window (state.tree_width, set in M.open())
-- minus this row's own actual indent, so a long CLR type name (e.g.
-- System.Reflection.RuntimeAssembly) gets a graceful '…' instead of
-- running past the window edge and getting hard-clipped mid-word with no
-- ellipsis at all (wrap=false in the tree window, so anything past the
-- edge just silently disappears) -- without needlessly truncating
-- shallow rows that never needed the room reserved for deep ones.
--
-- RIGHT_EDGE_MARGIN reserves a couple of blank cells so a truncated
-- type's own '…' doesn't land flush against the tree window's right
-- border with zero breathing room -- confirmed live via a zoomed-in
-- screenshot crop: the ellipsis WAS correctly present (truncation itself
-- was never broken by this point), it was just touching the border,
-- which read as "still not right" the same way the earlier Value/Type
-- gap issue did. Name/Value never hit this because GAP already reserves
-- room before the *next column*; Type is the last column, so nothing
-- was reserving room before the *window edge*.
local RIGHT_EDGE_MARGIN = 2

local function col_type_width(var)
  if not state.tree_width then
    return FALLBACK_COL_TYPE
  end
  return math.max(state.tree_width - COL_NAME - COL_VALUE - estimate_indent(var) - RIGHT_EDGE_MARGIN, MIN_COL_TYPE)
end

-- Icon glyphs/highlights use vim.fn.strdisplaywidth (not #s / byte length)
-- for width measurement and truncation, since both the disclosure
-- triangles and type icons below are multi-byte UTF-8 -- byte length
-- overcounts their actual terminal column width and would throw off the
-- fixed-width column alignment pad() exists to guarantee. Truncation
-- walks character-by-character (vim.fn.strcharpart) rather than byte
-- slicing so it can't cut a multi-byte glyph in half.
-- GAP is the minimum blank cells always left between this column and the
-- next, even when the value is truncated with '…' -- a single trailing
-- space read as no gap at all once the ellipsis glyph's own visual
-- weight is factored in (reported live: a truncated AssemblyQualifiedName
-- looked like it ran straight into the Type column with 1 space).
local GAP = 2

-- Truncates to at most max_width display cells, appending '…' if it had
-- to cut anything. Used directly for the Type column (last column,
-- nothing after it to pad out to), and by pad() below (Name/Value
-- columns, which additionally get padded to a fixed width).
local function truncate(s, max_width)
  s = tostring(s or ''):gsub('\n', ' ')
  if vim.fn.strdisplaywidth(s) <= max_width then
    return s
  end
  local truncated = s
  while vim.fn.strdisplaywidth(truncated) > max_width - 1 do
    truncated = vim.fn.strcharpart(truncated, 0, vim.fn.strchars(truncated) - 1)
  end
  return truncated .. '…'
end

local function pad(s, width)
  local truncated = truncate(s, width - GAP)
  return truncated .. string.rep(' ', width - vim.fn.strdisplaywidth(truncated))
end

local ICON_EXPANDED, ICON_COLLAPSED, ICON_LEAF = '▾', '▸', ' '

-- Same glyphs and BlinkCmpKind* highlight groups blink.cmp's own default
-- kind_icons use (lua/blink/cmp/config/appearance.lua) -- reused here
-- rather than picking new ones so the tree matches the icons already
-- shown in this same box's own completion popup. DAP variable/evaluate
-- responses don't carry real completion-item-kind metadata the way an
-- LSP does (there's no method/field/property distinction -- QuickWatch's
-- tree only ever shows values, never method signatures), so this is a
-- coarse classification from what IS available (has_children, CLR type
-- name), not a full kind mapping.
local TYPE_ICON_CLASS = { glyph = '󱡠', hl = 'BlinkCmpKindClass' } -- expandable: array/class/struct/record
local TYPE_ICON_VALUE = { glyph = '󰦨', hl = 'BlinkCmpKindValue' } -- numeric/bool leaf
local TYPE_ICON_TEXT  = { glyph = '󰉿', hl = 'BlinkCmpKindText' }  -- string/char leaf
local TYPE_ICON_FIELD = { glyph = '󰜢', hl = 'BlinkCmpKindField' } -- anything else leaf

local NUMERIC_BOOL_TYPES = {
  int = true, long = true, short = true, sbyte = true,
  uint = true, ulong = true, ushort = true, byte = true,
  float = true, double = true, decimal = true, bool = true, boolean = true,
}

local function type_icon(var, has_children)
  if has_children then
    return TYPE_ICON_CLASS
  end
  local t = var.type and var.type:lower() or ''
  if NUMERIC_BOOL_TYPES[t] then
    return TYPE_ICON_VALUE
  end
  if t == 'string' or t == 'char' then
    return TYPE_ICON_TEXT
  end
  return TYPE_ICON_FIELD
end

-- `evaluateName` (a full expression path, e.g. "forecast[0].TemperatureC")
-- is present on every child dap.Variable dncdbg returns and is stable
-- across reevaluate() calls of the same expression text, unlike `.name`
-- alone (which collides across siblings at different depths, e.g. two
-- unrelated "[0]" rows). Root responses have neither -- there's only ever
-- one root visible at a time, so a constant key is fine.
local function node_key(var)
  return var.evaluateName or var.name or '__root__'
end

-- dap.ui's own with_indent (dap/ui.lua) is a local, not exported --
-- reimplemented here so toggle_at_cursor below can re-render a single
-- already-indented row through the same render_row function dap.ui
-- itself uses for that row, without needing dap.ui's internals.
local function with_indent(indent, fn)
  return function(...)
    local text, hl_groups = fn(...)
    return string.rep(' ', indent) .. text, vim.tbl_map(function(hl)
      local end_col = hl[3] == -1 and -1 or hl[3] + indent
      return { hl[1], hl[2] + indent, end_col }
    end, hl_groups or {})
  end
end

-- Used as both render_parent and render_child on a copy of
-- dap.entity.variable.tree_spec. dap.ui only ever calls this with a
-- single `var` argument -- indentation for child rows is applied by a
-- wrapper closure in dap.ui itself (dap/ui.lua's with_indent), so this
-- function never needs to know its own depth. Column widths are fixed
-- rather than auto-fit to content: true per-content column sizing would
-- require re-measuring and re-rendering the whole visible tree on every
-- expand/collapse, which dap.ui's incremental line-range rendering isn't
-- built for. Deeply nested rows will drift out of column alignment as
-- indentation eats into the Name column -- acceptable for the common
-- 1-2 level nesting case this is meant for.
--
-- The disclosure triangle reflects dap_quickwatch's own state.expanded
-- tracking (see toggle_at_cursor), not dap.ui's internal expand state --
-- that's private to dap.ui's tree object and dap.ui never re-renders a
-- row's own line on expand/collapse (only the child lines below it
-- change), so there'd be nothing to read it from even if it were public.
local function render_row(var)
  local has_children = entity.variable.has_children(var)
  local key = node_key(var)
  local disclosure = has_children
      and (state.expanded and state.expanded[key] and ICON_EXPANDED or ICON_COLLAPSED)
      or ICON_LEAF
  local icon = type_icon(var, has_children)

  local name = var.name or '(root)'
  local value = var.value or var.result or ''
  -- truncate(), not pad(): Type is the last column, nothing to its right
  -- needs it padded to a fixed width -- only capped so a long CLR type
  -- name can't run past the tree window's edge and get hard-clipped
  -- mid-word (e.g. "System.Reflection.RuntimeAssembly" cut to
  -- "System.Reflection.RuntimeAssembl" with no ellipsis at all).
  local typ = truncate(var.type or '', col_type_width(var))

  local name_field = disclosure .. ' ' .. icon.glyph .. ' ' .. name
  local name_padded = pad(name_field, COL_NAME)
  local value_padded = pad(value, COL_VALUE)
  local text = name_padded .. value_padded .. typ

  local icon_start = #disclosure + 1
  local name_start = icon_start + #icon.glyph + 1
  -- name_start + #name assumes the *full* name is present in name_padded,
  -- but pad() truncates name_field (disclosure+icon+name) when it doesn't
  -- fit COL_NAME -- when that happens, the actual name text in the output
  -- ends earlier than name_start + #name, at #name_padded (everything
  -- after that is pad()'s own trailing spaces, not part of the name at
  -- all). Without this min(), the 'Identifier' highlight kept using the
  -- untruncated end offset and overran into the Value column's own text
  -- -- confirmed live: a truncated name's row showed its Value ("false")
  -- colored the same purple as the name, while the untruncated sibling
  -- row correctly showed it in the default color.
  local name_end = math.min(name_start + #name, #name_padded)

  return text, {
    { icon.hl,      icon_start, icon_start + #icon.glyph },
    { 'Identifier', name_start, name_end },
    -- #name_padded + #value_padded (actual BYTE length), not
    -- COL_NAME + COL_VALUE (display-cell width) -- pad() guarantees the
    -- latter as *display width*, but every row's disclosure triangle and
    -- kind icon are multi-byte nerd-font glyphs (4 bytes each, 1-2
    -- display cells), so byte length runs ahead of display width by a
    -- few bytes on every single row. Using the display-width constant
    -- here landed this highlight a few bytes too early -- confirmed via
    -- a direct extmark test (off by exactly the icon glyphs' byte
    -- overhead) -- coloring the tail of the Value column's own text/
    -- padding as if it were Type text. Most visible on truncated/near-
    -- full values, which is why it read as "the ellipsis has no gap
    -- before it" even after pad() itself was already correct.
    { 'Type',       #name_padded + #value_padded, -1 },
  }
end

-- 'winborder' exists as an option from Neovim 0.11 on but defaults to ''
-- (no border) unless the user has set it -- nvim-dap's own float helpers
-- fall back to 'single' only when the option doesn't *exist* at all, which
-- means on a stock 0.11+ config with 'winborder' unset they silently render
-- with no border/title either. Fall back on emptiness too, matching the
-- "rounded" style dap-view.lua already uses for the DAP scopes float.
local function border()
  local wb = vim.o.winborder
  if wb and wb ~= '' then
    return wb
  end
  return 'rounded'
end

local function current_expr()
  if not (state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf)) then
    return nil
  end
  return vim.trim(vim.api.nvim_buf_get_lines(state.input_buf, 0, 1, true)[1] or '')
end

local function focus_tree()
  if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
    vim.api.nvim_set_current_win(state.tree_win)
  end
end

-- Re-enters insert mode on landing, matching M.open()'s own initial
-- startinsert! -- the expression box exists to be typed into, so jumping
-- back to it via <Tab> should let the user continue typing immediately
-- rather than requiring an extra `i`.
local function focus_input()
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_set_current_win(state.input_win)
    vim.cmd('startinsert!')
  end
end

-- Methods that take a lambda but aren't implemented in dncdbg's evaluator
-- yet (see EvaluateLinqPredicateMethod/EvaluateLinqWhereMethod/
-- EvaluateLinqSelectMethod/EvaluateLinqSelectManyMethod/
-- EvaluateLinqOrderByMethod in evalstackmachine.cpp -- only
-- Any/All/Count/First/Where/Select/SelectMany/OrderBy are, as of the
-- feat/linq-orderby-lambda branch). `Where`, `Select`, and `SelectMany`
-- used to be in this list too -- `Where` had been observed to hang
-- indefinitely when evaluated through easy-dotnet's attach-mode proxy,
-- but that turned out to be an unrelated proxy bug (a slow completions
-- request blocking the whole client message pipe, fixed in
-- easy-dotnet-server, not specific to Where) rather than anything about
-- Where itself -- all four are now confirmed working live through the
-- real attach-mode flow.
--
-- Note: projecting to, filtering, or sorting an array of a non-primitive
-- value type (a struct, e.g. DateOnly) fails with a clear dncdbg-side
-- error for Where/Select/SelectMany/OrderBy -- a real, currently-
-- unresolved CoreCLR-level limitation (see dncdbg's git log on the
-- feat/linq-select-lambda branch), not a hang, so it's left to dncdbg's
-- own error rather than blocked here. OrderBy has its own additional key-
-- type limitation on top of that: the sort key itself must be a
-- primitive, bool, char, or string -- sorting by anything else (even a
-- perfectly ordinary class/record) also errors cleanly rather than
-- working, since comparing two arbitrary .NET values would need calling
-- their own CompareTo/operator< via func-eval once per comparison the
-- sort makes, not implemented.
local UNSUPPORTED_LAMBDA_METHODS = {
  'OrderByDescending',
  'ThenBy', 'ThenByDescending', 'GroupBy', 'TakeWhile', 'SkipWhile',
  'Aggregate', 'ForEach',
}

local function find_unsupported_lambda_method(expr)
  if not expr:find('=>', 1, true) then
    return nil
  end
  for _, name in ipairs(UNSUPPORTED_LAMBDA_METHODS) do
    if expr:find('%.' .. name .. '%s*%(') then
      return name
    end
  end
  return nil
end

function M.close()
  signature.hide()
  for _, win in ipairs({ state.input_win, state.tree_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  state = {}
end

local function render_tree_lines(lines)
  if not (state.tree_buf and vim.api.nvim_buf_is_valid(state.tree_buf)) then
    return
  end
  state.layer.render(lines, tostring, nil, 2, -1)
end

-- Wraps dap.ui.trigger_actions() to keep render_row's disclosure triangle
-- in sync. Doesn't try to predict whether the action that ran was
-- actually "expand"/"collapse" (dap.entity.variable.tree_spec's
-- compute_actions can offer others -- copy expression, add to watches,
-- set value -- and QuickWatch inherits all of them unmodified); instead
-- it observes the ground truth after the action runs, by checking
-- whether the line below the toggled row now has a deeper indent than
-- before. That's robust regardless of which action actually fired: a
-- non-expand action leaves the surrounding indentation exactly as it
-- was, so it's a no-op for expand tracking either way.
--
-- Then re-renders just that one row's own line (dap.ui's expand/collapse
-- only ever inserts/removes the *children* lines below it, never
-- re-renders the toggled row itself) so the flipped icon is visible
-- immediately rather than only after the next reevaluate().
local function toggle_at_cursor(opts)
  local win = vim.api.nvim_get_current_win()
  local lnum, col = unpack(vim.api.nvim_win_get_cursor(win))
  lnum = lnum - 1
  local info = state.layer and state.layer.get(lnum, 0, col)
  local item = info and info.item

  if not item or not entity.variable.has_children(item) then
    ui.trigger_actions(opts)
    return
  end

  ui.trigger_actions(opts)

  local buf = state.tree_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local this_line = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1] or ''
  local next_line = vim.api.nvim_buf_get_lines(buf, lnum + 1, lnum + 2, false)[1] or ''
  local this_indent = #(this_line:match('^%s*'))
  local next_indent = #(next_line:match('^%s*'))
  local now_expanded = next_indent > this_indent

  state.expanded[node_key(item)] = now_expanded or nil

  local indent = (info.context and info.context.indent) or 0
  local render = indent > 0 and with_indent(indent, render_row) or render_row
  state.layer.render({ item }, render, info.context, lnum, lnum + 1)
end

function M.reevaluate()
  local expr = current_expr()
  if not expr or expr == '' then
    return
  end

  local unsupported = find_unsupported_lambda_method(expr)
  if unsupported then
    render_tree_lines({
      ('"%s" with a lambda isn\'t supported yet'):format(unsupported),
      '(only Any/All/Count/First/Where/Select/SelectMany/OrderBy are) --',
      'dncdbg returns a clean error for this one, but not sent',
      'client-side to save the round-trip.',
    })
    return
  end

  local session = require('dap').session()
  if not session then
    vim.notify('QuickWatch: no active debug session', vim.log.levels.WARN)
    return
  end

  state.eval_generation = (state.eval_generation or 0) + 1
  local my_generation = state.eval_generation
  local done = false
  -- Captured before the request is sent so the timeout handler below can
  -- ask the adapter to cancel this specific request if it never answers.
  local eval_request_seq = session.seq

  -- context = "watch" (not "hover"): adapters commonly restrict
  -- side-effecting expressions like method calls under "hover" context
  -- to avoid side effects from passive mouse-hover, but allow them under
  -- "watch"/"repl" -- this is explicit user-triggered reevaluation, not
  -- passive hover, so "watch" is the correct signal (matches what
  -- nvim-dap-ui's own Watches panel uses).
  session:evaluate({ expression = expr, context = 'watch' }, function(err, resp)
    vim.schedule(function()
      done = true
      if my_generation ~= state.eval_generation then
        return -- superseded by a newer reevaluate() call
      end
      if err then
        render_tree_lines({ ('Error evaluating "%s":'):format(expr), tostring(err.message or err) })
        return
      end
      if not (state.tree_buf and vim.api.nvim_buf_is_valid(state.tree_buf)) then
        return
      end
      -- dap.ui's tree.render() always force-expands the root on every
      -- call regardless of any prior collapse (see dap/ui.lua's own
      -- render()) -- mirror that here so render_row's disclosure
      -- triangle for the root matches what's actually about to be shown,
      -- rather than staying "▸" from a collapse earlier in this session.
      state.expanded[node_key(resp)] = true
      state.tree.render(state.layer, resp, nil, 2, -1)
    end)
  end)

  -- netcoredbg (and presumably other adapters) can silently hang rather
  -- than error on certain expressions -- observed concretely for direct
  -- member/method access on array-typed root expressions (`forecast.Length`,
  -- `forecast.First()` never call back at all, while the equivalent
  -- `forecast[0].Foo` resolves in milliseconds). Surface that as an
  -- explicit timeout instead of leaving the tree pane looking inertly
  -- unchanged, which is what made this look like nothing was happening.
  vim.defer_fn(function()
    if done or my_generation ~= state.eval_generation then
      return
    end
    -- Ask the adapter to abandon the still-in-flight request (DAP
    -- `cancel`, per capabilities.supportsCancelRequest) instead of just
    -- walking away from it locally. Giving up locally without telling the
    -- adapter leaves the original request dangling; since func-eval-style
    -- requests are commonly processed one at a time, that can affect
    -- requests sent afterward, not just this one -- best-effort, fire and
    -- forget, nothing here depends on it actually succeeding.
    if session.capabilities and session.capabilities.supportsCancelRequest then
      pcall(function()
        session:request('cancel', { requestId = eval_request_seq }, function() end)
      end)
    end
    render_tree_lines({
      ('Timed out evaluating "%s"'):format(expr),
      'The debug adapter never responded (>10s) -- some adapters hang',
      'rather than error on certain expressions (e.g. netcoredbg on',
      'direct array member/method access -- try indexing first).',
      '',
      'WARNING: on CoreCLR a timed-out func-eval that fails to abort',
      'cleanly can leave the whole debug session unusable (not just this',
      'expression) -- if stepping/continuing/breakpoints stop responding',
      'too, restart the debug session rather than trying to work around it.',
    })
    -- The tree pane is easy to miss/scroll past; the same "session may be
    -- unusable now" risk deserves a notification that doesn't depend on
    -- the user still looking at QuickWatch when it happens.
    vim.notify(
      ('QuickWatch: "%s" timed out -- if the rest of the debug session ' ..
        'stops responding too, restart it (CoreCLR func-eval timeouts can ' ..
        'corrupt the session, not just this expression)'):format(expr),
      vim.log.levels.WARN
    )
  end, 10000)
end

-- Visual Studio's QuickWatch hides an array's own inherited properties
-- (Length, Rank, etc.) by default under an array node, showing only its
-- indexed elements -- a client-side display filter (VS calls the
-- unfiltered version "Raw View"), not something the debug protocol
-- itself distinguishes: dncdbg's own `variables` response for an array
-- mixes indexed elements and properties together in one flat list.
-- Replicated the same way, filtering to names shaped like "[0]" or (for
-- multi-dimensional arrays) "[0, 1]".
local function is_array_type(var)
  return type(var.type) == 'string' and var.type:match('%[%]$') ~= nil
end

local function filter_array_children(var, children)
  if not is_array_type(var) then
    return children
  end
  return vim.tbl_filter(function(child)
    return child.name and child.name:match('^%[[%d, ]+%]$') ~= nil
  end, children)
end

function M.add_watch()
  local expr = current_expr()
  if not expr or expr == '' then
    return
  end
  require('dapui').elements.watches.add(expr)
  vim.notify('QuickWatch: added watch "' .. expr .. '"', vim.log.levels.INFO)
end

---@param prefill string|nil
function M.open(prefill)
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_set_current_win(state.input_win)
    vim.cmd('startinsert!')
    return
  end

  prefill = prefill or ''
  state.expanded = {}
  local total_width = math.floor(vim.o.columns * 0.6)
  -- Read by render_row to cap the Type column to whatever room is
  -- actually left in the tree window, rather than a fixed guess -- the
  -- window's own width varies with vim.o.columns (see total_width
  -- above), so a fixed cap could still get hard window-clipped (no
  -- ellipsis at all, since wrap=false) on a narrower terminal, or waste
  -- space on a wider one.
  state.tree_width = total_width
  local input_height = 1
  local tree_height = math.floor(vim.o.lines * 0.5)
  local b = border()
  local border_rows = (b == 'none') and 0 or 2
  local total_height = input_height + border_rows + tree_height
  local row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)

  -- Input float: stays fully editable/modifiable the whole time, so it
  -- can't share a buffer with the tree (see module comment above).
  state.input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.input_buf].buftype = 'nofile'
  vim.bo[state.input_buf].bufhidden = 'wipe'
  vim.bo[state.input_buf].swapfile = false
  -- Filetype stays 'dap-quickwatch-input' (blink/completion routing keys
  -- off it) -- C# highlighting is attached separately via the legacy
  -- 'syntax' option, not treesitter. Tried treesitter first: the C#
  -- grammar wraps a bare expression with no trailing ';' (which every
  -- QuickWatch expression is) in a synthetic ERROR node during error
  -- recovery, and Neovim's treesitter highlighter suppresses captures
  -- inside ERROR nodes -- so real subnodes (numbers, member access, ...)
  -- parsed fine but nothing actually rendered. Legacy regex-based syntax
  -- highlighting has no notion of "syntax error" to begin with, so it
  -- doesn't hit this at all; confirmed against the same fragment.
  vim.bo[state.input_buf].filetype = 'dap-quickwatch-input'
  vim.bo[state.input_buf].syntax = 'cs'

  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = total_width,
    height = input_height,
    border = b,
    style = 'minimal',
    title = ' Expression  (<CR> reevaluate, <Tab> results, <leader>a watch, <Esc> close) ',
    title_pos = 'center',
  })

  -- Tree float: header/separator written directly (not through the
  -- dap.ui layer, which has ambiguous first-insert behavior on a fresh
  -- scratch buffer) while the buffer is still modifiable, then locked.
  state.tree_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.tree_buf].buftype = 'nofile'
  vim.bo[state.tree_buf].bufhidden = 'wipe'
  vim.bo[state.tree_buf].swapfile = false
  vim.bo[state.tree_buf].filetype = 'dap-quickwatch-tree'

  local header = pad('Name', COL_NAME) .. pad('Value', COL_VALUE) .. 'Type'
  vim.api.nvim_buf_set_lines(state.tree_buf, 0, -1, false,
    { header, string.rep('─', math.max(total_width - 2, 1)) })
  vim.bo[state.tree_buf].modifiable = false

  -- Routed through toggle_at_cursor (not straight to dap.ui.trigger_actions)
  -- so the disclosure triangle stays in sync -- see its comment above.
  vim.keymap.set('n', '<CR>', function() toggle_at_cursor({ mode = 'first' }) end,
    { buffer = state.tree_buf })
  vim.keymap.set('n', 'a', function() toggle_at_cursor() end, { buffer = state.tree_buf })
  vim.keymap.set('n', 'o', function() toggle_at_cursor() end, { buffer = state.tree_buf })
  vim.keymap.set('n', '<Tab>', focus_input, { buffer = state.tree_buf })

  state.tree_win = vim.api.nvim_open_win(state.tree_buf, false, {
    relative = 'editor',
    row = row + input_height + border_rows,
    col = col,
    width = total_width,
    height = tree_height,
    border = b,
    style = 'minimal',
    title = ' Name / Value / Type  (<Tab> expression, <Esc>/q close) ',
    title_pos = 'center',
  })
  vim.wo[state.tree_win].wrap = false
  vim.wo[state.tree_win].scrolloff = 0

  state.layer = ui.layer(state.tree_buf)
  local spec = vim.tbl_extend('force', entity.variable.tree_spec, {
    render_parent = render_row,
    render_child = render_row,
    get_children = function(var)
      return filter_array_children(var, entity.variable.get_children(var))
    end,
    fetch_children = function(var, cb)
      entity.variable.fetch_children(var, function(children)
        cb(filter_array_children(var, children))
      end)
    end,
  })
  state.tree = ui.new_tree(spec)

  vim.api.nvim_buf_set_lines(state.input_buf, 0, 1, false, { prefill })
  vim.api.nvim_win_set_cursor(state.input_win, { 1, #prefill })
  vim.cmd('startinsert!')

  -- <CR> always means Reevaluate here, never "accept completion" -- it
  -- previously deferred to blink's accept() whenever the menu was open,
  -- but blink preselects the first item by default (completion.list.
  -- selection.preselect), so *any* time the popup had items when <CR>
  -- was pressed, it silently inserted that completion instead of
  -- reevaluating -- looked like "reevaluate stopped working" after
  -- editing the expression, since typing itself reopens the menu. Just
  -- dismiss the menu (if open) and reevaluate unconditionally; accepting
  -- a completion is still available via blink's own Tab/<C-y> bindings.
  vim.keymap.set('i', '<CR>', function()
    local ok, blink = pcall(require, 'blink.cmp')
    if ok then
      pcall(blink.hide)
    end
    vim.cmd('stopinsert')
    M.reevaluate()
  end, { buffer = state.input_buf })
  vim.keymap.set('n', '<CR>', M.reevaluate, { buffer = state.input_buf })

  -- <Tab> switches focus to the results pane, but only when there's no
  -- completion menu open to navigate -- blink's super-tab preset (see
  -- blink.lua) already owns <Tab> for accept/select-next whenever the
  -- menu is visible, and a buffer-local mapping here would otherwise
  -- shadow that unconditionally (same class of bug <CR> hit above: don't
  -- blindly override a key blink is already using contextually).
  vim.keymap.set('i', '<Tab>', function()
    local ok, blink = pcall(require, 'blink.cmp')
    if ok and blink.is_menu_visible() then
      blink.select_and_accept()
      return
    end
    vim.cmd('stopinsert')
    focus_tree()
  end, { buffer = state.input_buf })
  vim.keymap.set('n', '<Tab>', focus_tree, { buffer = state.input_buf })

  -- Real Roslyn signature help (parameter hints, overload cycling) --
  -- see roslyn_watch_signature for the full rationale (blink's own
  -- signature help is disabled project-wide and can't cycle overloads;
  -- lsp-overloads.nvim only resolves against the *current* buffer's LSP
  -- client, which the QuickWatch scratch buffer has none of).
  --
  -- Triggered on '(' and ',' (opening a call / moving to the next
  -- argument) and dismissed on ')' (closing it) -- checked here rather
  -- than via InsertCharPre because TextChangedI already fires after the
  -- buffer reflects the typed character, so the popup shows the
  -- signature reflecting what's actually on the line, not what's about
  -- to be inserted.
  vim.api.nvim_create_autocmd('TextChangedI', {
    buffer = state.input_buf,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local col = vim.api.nvim_win_get_cursor(win)[2]
      local line = vim.api.nvim_get_current_line()
      local before_cursor = line:sub(1, col)
      local trigger_char = before_cursor:sub(-1)
      if trigger_char == '(' or trigger_char == ',' then
        signature.trigger()
      elseif trigger_char == ')' then
        signature.hide()
      end
    end,
  })
  vim.api.nvim_create_autocmd('InsertLeave', {
    buffer = state.input_buf,
    callback = signature.hide,
  })

  -- <C-k> confirmed unclaimed by blink.cmp (its own signature help is
  -- disabled, see blink.lua) -- triggers a fresh signature-help lookup if
  -- nothing is showing, or cycles to the next overload of an
  -- already-shown one without another LSP round trip.
  vim.keymap.set('i', '<C-k>', function()
    if signature.is_visible() then
      signature.cycle()
    else
      signature.trigger()
    end
  end, { buffer = state.input_buf })

  if prefill ~= '' then
    M.reevaluate()
  end
end

return M
