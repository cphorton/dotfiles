-- "directory" nodes toggle, "file" nodes open, exactly like the filesystem
-- source, so everything except "refresh" comes straight from the common
-- command set (every built-in source defines its own refresh -- there's no
-- shared default because what "refresh" means differs per source).
local cc = require("neo-tree.sources.common.commands")

local M = {}

M.refresh = function(state)
  require("neo-tree.sources.manager").refresh(state.name)
end

--- The add-package flow is actually two sequential floating pickers (search,
--- then version selection), each of which knocks out neo-tree's floating
--- window underneath it -- neo-tree floats unmount themselves once their
--- buffer isn't displayed anywhere, and that's what opening another float
--- over them causes. Fixed-delay retries after the RPC's completion callback
--- don't work: that callback only fires once the *whole* flow (both pickers
--- plus the `dotnet add/remove package` run) is done, so guessed-delay
--- retries end up racing the tail end of that instead of the actual picker
--- transitions, and lose.
---
--- Reopening on the real signal instead: `WinClosed` fires the instant any
--- floating window closes, including each picker. So react to that directly
--- -- the moment the version-selection picker closes (or the search picker,
--- or anything else), check whether the dotnet float is missing and restore
--- it right then. This also means we never touch the tree while a picker is
--- still open and the user is actively typing/selecting in it, since nothing
--- fires until something actually closes.
---
--- action = "focus", not "show": "show" captures whatever window is current,
--- navigates asynchronously, and afterward tries to re-focus that captured
--- window -- see do_show_or_focus() in neo-tree's command/init.lua. With
--- WinClosed firing repeatedly in a burst (each picker closing), that
--- captured window can already be gone by the time the async hop-back runs,
--- throwing "Invalid window id" from inside a vim.schedule callback
--- (confirmed live). "focus" has no such captured-window step, so it
--- sidesteps the race instead of trying to win it.
local function reopen()
  require("neo-tree.command").execute({ action = "focus", source = "dotnet", position = "float" })
end

--- Neither "skip N closes" nor "wait for N ms of no closes" actually works:
--- both are guessing at timing/step-count from indirect signals. If the user
--- takes their time browsing the still-open version picker, that also looks
--- "quiet" -- nothing has closed recently -- even though it's very much
--- still open (confirmed live: reopened while the version picker was still
--- sitting there, just not yet closed). The only signal that's actually
--- correct is checking reality directly: is any *other* floating window
--- currently open?
---
--- But not *every* float should count as blocking -- the "Progress .../
--- Restoring packages..." toast is also a floating window, and the user
--- specifically wants that one ignored: reopen as soon as the version picker
--- itself closes, regardless of whether that toast is still spinning
--- (literally spinning -- its animation is nvim-notify's own spring-physics
--- WindowAnimator). This config routes vim.notify through noice.nvim, which
--- uses nvim-notify (rcarriga/nvim-notify) as its rendering backend (see
--- lua/plugins/noice.lua's dependencies) -- NOT Snacks' notifier, despite
--- Snacks also being installed. nvim-notify tags its buffers with
--- filetype = "notify" (nvim-notify/lua/notify/service/buffer/init.lua), so
--- that's the one that actually matters here. Also skip "snacks_notif" in
--- case Snacks' own notifier is ever the active one instead (e.g. after a
--- noice config change), and skip non-focusable floats generally (covers
--- decorative overlays like Snacks' own picker backdrop, which sets
--- `focusable = false` for the same "don't count this" reason). Anything
--- else -- namely the actual interactive pickers, which have to be focusable
--- since you type/select in them -- still counts as blocking.
local IGNORED_FILETYPES = { notify = true, snacks_notif = true }

local function any_other_float_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
    if ok and cfg.relative and cfg.relative ~= "" and cfg.focusable ~= false then
      local buf = vim.api.nvim_win_get_buf(win)
      if not IGNORED_FILETYPES[vim.bo[buf].filetype] then
        return true
      end
    end
  end
  return false
end

--- "Nothing blocking is floating right now" is *not* enough by itself for
--- the add-package flow: it's also true during the gap between the search
--- picker closing and the version picker opening, while the server is
--- fetching the package's version list (the only thing floating during that
--- gap is the ignored "Fetching versions for X..." toast). Reopening there
--- pops the tree back up underneath the not-yet-shown version picker
--- (confirmed live from a screenshot: tree, toast, and the about-to-appear
--- version picker all visible together -- the reopen had already fired).
---
--- Window state alone can't tell that gap apart from "actually done", since
--- both look like "nothing real is floating". What *can* tell them apart is
--- the RPC layer: the add flow always drives exactly two interactive picker
--- requests in order -- "picker/live" for the search, then "picker/pick" for
--- the version list (title "Pick version for <package>", matching the
--- picker's on-screen title -- confirmed live from a screenshot).
---
--- Patch *this* module (`easy-dotnet.picker`'s `server_picker`/`server_live`)
--- and not `easy-dotnet.rpc.handlers.picker.picker_handler`'s `pick`/`live`,
--- even though the latter is what "picker/pick"/"picker/live" more directly
--- map to -- confirmed live this actually matters, not just theoretical:
--- patching picker_handler silently intercepted nothing, and reopen only
--- ever fired from the unconditional final RPC-completion callback (visibly
--- in sync with the "Added successfully" toast seconds later, instead of the
--- version picker closing). Root cause: `rpc-client.lua` builds its
--- method-name dispatch table once at module load time as
--- `handlers["picker/pick"] = require(picker_handler).pick` -- a captured
--- function *value*, frozen at that moment. Reassigning
--- `picker_handler.pick` afterwards changes the module table's field, but
--- the already-captured value in `handlers` still points at the original
--- function object; dispatch never looks the field up again. `picker_handler
--- .pick`'s *body*, though, does `require("easy-dotnet.picker")
--- .server_picker(...)` -- a fresh require+field-lookup on every call, not
--- captured anywhere -- so patching the field it reads each time actually
--- gets seen by real dispatch, regardless of load order.
---@param params table picker/pick or picker/live RPC params (has .prompt)
---@param on_final fun() called once, when a request matching is_final
---  answers (response invoked), before forwarding the response onward
---@return fun() unwrap
local function wrap_picker_handler(is_final_picker, on_final)
  local picker = require("easy-dotnet.picker")
  local orig_server_picker, orig_server_live = picker.server_picker, picker.server_live
  local fired = false

  local function wrap(orig)
    return function(params, response)
      return orig(params, function(...)
        if not fired and is_final_picker(params) then
          fired = true
          on_final()
        end
        return response(...)
      end)
    end
  end

  picker.server_picker = wrap(orig_server_picker)
  picker.server_live = wrap(orig_server_live)

  return function()
    picker.server_picker = orig_server_picker
    picker.server_live = orig_server_live
  end
end

---@param is_final_picker (fun(params: table): boolean)|nil predicate
---  matching the picker/pick or picker/live RPC request whose answer means
---  the flow's interactive part is done (see wrap_picker_handler above).
---  Pass nil for flows that never open an interactive picker at all (e.g.
---  remove, which supplies package_ids up front specifically to skip its
---  picker) -- reopening is then gated on window state alone, same as before
---  this predicate existed.
---@return fun() stop
local function watch_for_reopen(is_final_picker)
  local renderer = require("neo-tree.ui.renderer")
  local manager = require("neo-tree.sources.manager")
  local group = vim.api.nvim_create_augroup("neotree_dotnet_reopen", { clear = true })

  local final_picker_done = is_final_picker == nil
  local unwrap = is_final_picker
      and wrap_picker_handler(is_final_picker, function()
        final_picker_done = true
      end)
    or nil

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function()
      vim.schedule(function()
        if not pcall(vim.api.nvim_get_current_win) then
          return -- vim itself may be closing
        end
        local state = manager.get_state("dotnet")
        -- our own float not existing is exactly why we're here; nothing to
        -- exclude from the scan below since it's already gone
        if final_picker_done and not renderer.window_exists(state) and not any_other_float_open() then
          reopen()
        end
      end)
    end,
  })
  local stopped = false
  local function stop()
    if stopped then
      return
    end
    stopped = true
    pcall(vim.api.nvim_del_augroup_by_id, group)
    if unwrap then
      unwrap()
    end
  end
  -- safety net in case the RPC callback never fires (server crash, etc.)
  vim.defer_fn(stop, 30000)
  return stop
end

--- Matches the version-selection picker of the add-package flow -- see
--- wrap_picker_handler's doc comment for why this is the signal that
--- actually distinguishes "flow really done" from the pre-version-picker
--- "fetching versions" gap.
local function is_version_picker(params)
  return type(params.prompt) == "string" and params.prompt:match("^Pick version") ~= nil
end

--- Bound to 'a' on the "Packages" node (see lua/plugins/neotree.lua). Opens
--- easy-dotnet's own add-package flow scoped to the owning project -- its
--- node.path is that project's .csproj (see lib/solution.lua), same as what
--- `:Dotnet add package` would prompt you to pick manually. Goes one level
--- below the easy-dotnet.nuget wrapper (straight to package_manager:add) so
--- we get a completion callback to reopen on -- the wrapper doesn't expose one.
M.add_nuget_package = function(state)
  local node = state.tree:get_node()
  if not (node.extra and node.extra.dotnet_kind == "packages_group") then
    return
  end
  local client = require("easy-dotnet.rpc.rpc").global_rpc_client
  local stop_watching = watch_for_reopen(is_version_picker)
  client:initialize(function()
    client.package_manager:add(node.path, false, function()
      stop_watching()
      reopen()
    end)
  end)
end

--- Bound to 'd' on an individual package leaf. easy-dotnet.nuget's own
--- remove_nuget() only forwards project_path, which still prompts a package
--- picker server-side -- going one level down to package_manager:remove and
--- passing package_ids lets us skip that picker since we already know
--- exactly which package the cursor is on.
M.remove_nuget_package = function(state)
  local node = state.tree:get_node()
  if not (node.extra and node.extra.dotnet_kind == "package") then
    return
  end
  local client = require("easy-dotnet.rpc.rpc").global_rpc_client
  local stop_watching = watch_for_reopen()
  client:initialize(function()
    client.package_manager:remove(node.path, { node.extra.package_name }, function()
      stop_watching()
      reopen()
    end)
  end)
end

cc._add_common_commands(M)

return M
