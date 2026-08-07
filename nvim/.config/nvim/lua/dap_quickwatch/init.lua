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

local M = {}

local COL_NAME, COL_VALUE = 32, 44

---@type table
local state = {}

local function pad(s, width)
  s = tostring(s or ''):gsub('\n', ' ')
  if #s > width - 1 then
    return s:sub(1, width - 2) .. '…'
  end
  return s .. string.rep(' ', width - #s)
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
local function render_row(var)
  local name = var.name or '(root)'
  local value = var.value or var.result or ''
  local typ = var.type or ''
  local text = pad(name, COL_NAME) .. pad(value, COL_VALUE) .. typ
  return text, {
    { 'Identifier', 0, #name },
    { 'Type',       COL_NAME + COL_VALUE, -1 },
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

-- Methods that take a lambda but aren't implemented in dncdbg's evaluator
-- yet (see EvaluateLinqPredicateMethod in evalstackmachine.cpp -- only
-- Any/All/Count/First are). `Where` specifically has been observed to
-- hang indefinitely when evaluated through easy-dotnet's attach-mode
-- proxy, rather than the clean, fast "not supported" error it returns
-- under direct launch mode -- root cause not fully pinned down (dncdbg
-- itself answers in ~5ms either way; something in the proxy layer
-- appears to lose the response specifically for this case). Blocking
-- these client-side means the request is never sent in the first place,
-- rather than relying on the timeout below to recover cleanly from a
-- hang that, empirically, it doesn't always.
local UNSUPPORTED_LAMBDA_METHODS = {
  'Where', 'Select', 'SelectMany', 'OrderBy', 'OrderByDescending',
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

function M.reevaluate()
  local expr = current_expr()
  if not expr or expr == '' then
    return
  end

  local unsupported = find_unsupported_lambda_method(expr)
  if unsupported then
    render_tree_lines({
      ('"%s" with a lambda isn\'t supported yet'):format(unsupported),
      '(only Any/All/Count/First are) -- not sent, since it has been',
      'observed to hang indefinitely rather than error cleanly when',
      'evaluated through the attach-mode debug proxy.',
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
  local total_width = math.floor(vim.o.columns * 0.6)
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
    title = ' Expression  (<CR> reevaluate, <leader>a add watch) ',
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

  vim.api.nvim_buf_set_keymap(state.tree_buf, 'n', '<CR>',
    "<Cmd>lua require('dap.ui').trigger_actions({ mode = 'first' })<CR>", {})
  vim.api.nvim_buf_set_keymap(state.tree_buf, 'n', 'a',
    "<Cmd>lua require('dap.ui').trigger_actions()<CR>", {})
  vim.api.nvim_buf_set_keymap(state.tree_buf, 'n', 'o',
    "<Cmd>lua require('dap.ui').trigger_actions()<CR>", {})

  state.tree_win = vim.api.nvim_open_win(state.tree_buf, false, {
    relative = 'editor',
    row = row + input_height + border_rows,
    col = col,
    width = total_width,
    height = tree_height,
    border = b,
    style = 'minimal',
    title = ' Name / Value / Type ',
    title_pos = 'center',
  })
  vim.wo[state.tree_win].wrap = false
  vim.wo[state.tree_win].scrolloff = 0

  state.layer = ui.layer(state.tree_buf)
  local spec = vim.tbl_extend('force', entity.variable.tree_spec, {
    render_parent = render_row,
    render_child = render_row,
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

  if prefill ~= '' then
    M.reevaluate()
  end
end

return M
