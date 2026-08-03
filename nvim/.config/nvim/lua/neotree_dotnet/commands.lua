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

--- A package leaf's node.path is its *owning project's* .csproj (see
--- lib/solution.lua -- there's no on-disk file that "is" the package), so
--- neo-tree's default preview (`vim.fn.bufadd(node.path)`) would just show
--- that shared, not-package-specific file -- identical for every package
--- under one project. Preview.show() in neo-tree's own preview.lua already
--- has an escape hatch for exactly this: `extra.bufnr or
--- vim.fn.bufadd(path)` -- if node.extra.bufnr is set, it's used directly
--- and node.path is never consulted. So the fix doesn't touch Preview at
--- all: just populate that field, from easy-dotnet's own NuGet search RPC
--- (client.nuget:nuget_search -- the same one powering its add-package
--- search picker), before delegating to the real toggle_preview.
---
--- One persistent buffer per package name (not a fresh one per keypress) so
--- repeated toggling reuses it instead of leaking scratch buffers, and a
--- cache alongside it so re-previewing an already-fetched package is instant
--- and doesn't re-hit the network. `nuget_search` is a *search*, not an
--- exact-id lookup -- there's no "get one package by id" RPC -- so results
--- are filtered for an exact (case-insensitive) id match; NuGet ids are
--- case-insensitive-canonical, so exact-match-ignoring-case is correct, not
--- just a good-enough heuristic.
local package_preview_bufs = {}
--- name -> nil (never fetched) | "pending" | { lines: string[], rows: neotree_dotnet.PreviewRow[] }
local package_details_cache = {}

local function split_lines(text)
  return vim.split((text:gsub("\r\n", "\n")), "\n", { plain = true })
end

--- Tried markdown for this (a `**Label:**` bold-line format, then a pipe
--- table, both rendered via render-markdown.nvim) and dropped both: the
--- bold-line format's `**` markers stayed visible as literal text no matter
--- what (render-markdown.nvim deliberately doesn't touch inline emphasis at
--- all -- confirmed by reading its source, no "bold"/"strong" handling
--- anywhere in it), and the table version broke visually the moment any
--- cell's content was long enough to soft-wrap (confirmed live: a long
--- License URL) -- table borders are virt_text overlaying one specific
--- buffer line each, so a wrapped continuation just spills out underneath
--- with no border at all. Plain aligned text sidesteps both: pad every
--- label out to the same fixed width so the value column lines up
--- regardless of which fields a given package happens to have (not just the
--- longest label *present* -- that would shift the column depending on
--- which fields are missing as you move between packages), and if a long
--- value wraps, it's just an ordinary wrapped line, nothing to misalign.
--- Labels get bolded/underlined via our own extmarks instead of markdown
--- syntax -- see the Preview.show patch below for why that has to happen on
--- neo-tree's real internal preview buffer, not this one.
local LABEL_WIDTH = 12 -- longest label below ("Dependencies")

local PREVIEW_NS = vim.api.nvim_create_namespace("neotree_dotnet_preview")
--- `default = true` so a user's own colorscheme/config can still override
--- these without us clobbering it back on every reload.
vim.api.nvim_set_hl(0, "NeotreeDotnetPreviewTitle", { link = "Title", default = true })
vim.api.nvim_set_hl(0, "NeotreeDotnetPreviewLabel", { bold = true, default = true })
--- "Underlined"/"Number" rather than the newer "@markup.link.url"/"@number"
--- treesitter groups -- both are long-standing standard :h highlight-groups
--- that essentially every colorscheme defines something for, whereas the
--- treesitter-capture groups are only reliably populated by colorschemes
--- that specifically integrate with treesitter, a narrower bet.
vim.api.nvim_set_hl(0, "NeotreeDotnetPreviewUrl", { link = "Underlined", default = true })
vim.api.nvim_set_hl(0, "NeotreeDotnetPreviewNumber", { link = "Number", default = true })
--- Explicit user request: color dependency list entries the same as a
--- namespace reference in a C# `using` statement, and follow whatever the
--- active colorscheme does with that, not a fixed color. Linking to `@type`
--- itself, not the older `Type` group directly, is what makes that literally
--- true rather than approximately true: confirmed live via a real treesitter
--- highlights query against an actual `using Asp.Versioning;` line that a
--- namespace identifier there gets exactly the `@type` capture, and `@type`
--- is a Neovim-builtin default link (present even in a fresh session with
--- no C# file ever opened -- confirmed live), so it's always safe to use.
--- Colorschemes that specifically customize `@type` differently from the
--- classic `Type` group (some do) get followed correctly this way; the
--- URL/Number groups above didn't need this distinction since there's no
--- equally-specific "this is what a NuGet URL/count looks like" precedent
--- to match against.
vim.api.nvim_set_hl(0, "NeotreeDotnetPreviewNamespace", { link = "@type", default = true })

---@param label string
---@param value string
---@return string
local function format_row(label, value)
  return label .. ":" .. string.rep(" ", LABEL_WIDTH - #label + 1) .. value
end

--- The column a row's value starts at, matching format_row's own padding
--- scheme -- also where a wrapped continuation line needs to start, so it
--- lines up underneath.
local VALUE_COLUMN = LABEL_WIDTH + 2

--- 'linebreak' (see the Preview.show patch below) only wraps at word
--- boundaries -- it can't hang-indent a wrapped continuation to a *mid-line*
--- column the way 'breakindent' can to a line's own leading whitespace
--- (confirmed live via screenshot: a wrapped Tags value's continuation
--- started flush at column 0, not under the value column -- there's no
--- Neovim option for "hang-indent to wherever THIS line's content actually
--- started"). So hard-wrap long values ourselves instead, with continuation
--- lines given *real* leading spaces up to VALUE_COLUMN, rather than relying
--- on Neovim to wrap-and-indent a single long logical line. Width is chosen
--- comfortably below the preview window's typical size (neo-tree caps it at
--- 120 columns) so a further Neovim-driven soft-wrap on top of ours stays
--- unlikely in normal use; 'linebreak' is still left on as a fallback for
--- whatever isn't (e.g. an unusually narrow preview window).
local VALUE_WRAP_WIDTH = 70

---@param text string
---@param width integer
---@return string[] chunks word-wrapped at `width` columns, never splitting a word
local function wrap_words(text, width)
  local chunks = {}
  local line = ""
  for word in text:gmatch("%S+") do
    local candidate = line == "" and word or (line .. " " .. word)
    if #candidate > width and line ~= "" then
      table.insert(chunks, line)
      line = word
    else
      line = candidate
    end
  end
  if line ~= "" then
    table.insert(chunks, line)
  end
  return chunks
end

---@param label string
---@param value string
---@return string[] lines one or more -- more than one if `value` needed wrapping
local function format_row_wrapped(label, value)
  local chunks = wrap_words(value, VALUE_WRAP_WIDTH)
  if #chunks == 0 then
    chunks = { "" }
  end
  local out = { format_row(label, chunks[1]) }
  for i = 2, #chunks do
    table.insert(out, string.rep(" ", VALUE_COLUMN) .. chunks[i])
  end
  return out
end

---@alias neotree_dotnet.PreviewRow { first: integer, last: integer, kind: "number"|"url"|nil }
--- `first`/`last` are 1-based indices into `lines` -- more than one line
--- when the value wrapped. `kind` says which of NeotreeDotnetPreviewNumber/
--- Url to additionally paint over the *value* portion of every line in that
--- range (from VALUE_COLUMN onward -- always the same column regardless of
--- label length or whether it's a wrapped continuation, that's the point of
--- the alignment scheme); nil means no extra styling beyond the bold label.

---@param node neotree_dotnet.Node
---@param pkg easy-dotnet.Nuget.PackageMetadata
---@return string[] lines
---@return neotree_dotnet.PreviewRow[] rows
local function format_package_details(node, pkg)
  local lines = { pkg.title or pkg.id, "" }
  local rows = {}

  ---@param kind "number"|"url"|nil
  local function row(label, value, kind)
    if value and value ~= "" then
      local row_lines = format_row_wrapped(label, value)
      table.insert(rows, { first = #lines + 1, last = #lines + #row_lines, kind = kind })
      vim.list_extend(lines, row_lines)
    end
  end

  local installed = node.extra.installed_version
  if installed and installed ~= pkg.version then
    row("Installed", installed, "number")
    row("Latest", pkg.version, "number")
  else
    row("Version", pkg.version, "number")
  end
  row("Downloads", pkg.downloadCount and tostring(pkg.downloadCount) or nil, "number")
  row("Authors", pkg.authors)
  row("Tags", pkg.tags and #pkg.tags > 0 and table.concat(pkg.tags, ", ") or nil)
  row("Project", pkg.projectUrl, "url")
  row("License", pkg.licenseUrl, "url")

  local body = pkg.description
  if not body or body == "" then
    body = pkg.summary
  end
  if body and body ~= "" then
    table.insert(lines, "")
    vim.list_extend(lines, split_lines(body))
  end

  return lines, rows
end

--- Dependencies aren't in easy-dotnet's own NuGet metadata at all -- its
--- `nuget_search` RPC (confirmed by reading its Lua type annotation AND the
--- RPC-facing layer of easy-dotnet's own bundled server DLLs, `strings`-
--- searched for "DependencyGroup"/"PackageDependency": nothing) only
--- surfaces id/version/authors/description/tags/downloads/urls -- the
--- underlying NuGet.Protocol/NuGet.Packaging libraries it bundles fully
--- support dependency groups, easy-dotnet's own application layer just
--- doesn't ask for or forward them. So this bypasses easy-dotnet's server
--- and queries nuget.org directly instead, for this one piece of data only.
---
--- Uses the flat-container `.nuspec` endpoint
--- (`v3-flatcontainer/{id}/{version}/{id}.nuspec`, NuGet's documented
--- "PackageBaseAddress/3.0.0" resource -- verified live against the real
--- API) rather than the registration/catalog API: the registration index is
--- paginated for packages with many versions (some pages are inline, others
--- are just a URL to a separate blob needing a second fetch), while the
--- flat-container nuspec is one deterministic, always-inline URL per
--- package+version -- no pagination logic needed. Confirmed live against
--- real packages that dependency groups can be empty for some target
--- frameworks (self-closing `<group targetFramework="net6.0" />`, e.g.
--- Serilog on net5.0+ once a dependency became part of the runtime) --
--- results are deduped and sorted across all target frameworks into one
--- flat list, since a compact preview has no good place for a full
--- per-framework breakdown and most packages' framework-specific
--- dependency sets differ only by which runtime-provided pieces are needed.
---
--- Only ever attempted for packages actually resolved from nuget.org itself
--- (checked via the search result's own `source` field) -- explicit user
--- requirement: querying nuget.org directly for a package that actually
--- came from a private/internal feed would be wrong or simply return
--- nothing, so skip it entirely rather than show misleading data.
---
--- Version too, not just the id -- nuget.org's own package page shows each
--- dependency as "Id (>= version)" (confirmed live from a screenshot), and
--- that range is genuinely useful info, not just decoration. Extracts each
--- `<dependency .../>` tag's full attribute text and pulls `id`/`version`
--- back out of *that*, the same two-step `get_attr`-style approach
--- lib/solution.lua already uses for `.csproj` parsing, rather than
--- assuming attribute order in one combined pattern -- NuGet always emits
--- id-then-version in practice, but there's no reason to depend on that.
---@param id string
---@param version string
---@param cb fun(dependencies: { id: string, version: string }[]?) nil on
---  any failure (network, timeout, not found, no curl) -- always fails
---  silently, never errors
local function fetch_nuget_dependencies(id, version, cb)
  local url = string.format("https://api.nuget.org/v3-flatcontainer/%s/%s/%s.nuspec", id:lower(), version:lower(), id:lower())
  local function get_attr(attrs, attr_name)
    return attrs:match(attr_name .. '%s*=%s*"([^"]*)"')
  end
  local ok = pcall(vim.system, { "curl", "-s", "-f", "--max-time", "5", url }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 or not result.stdout or result.stdout == "" then
        cb(nil)
        return
      end
      local seen, deps = {}, {}
      for attrs in result.stdout:gmatch("<dependency%s+(.-)%s*/?>") do
        local dep_id = get_attr(attrs, "id")
        if dep_id and not seen[dep_id] then
          seen[dep_id] = true
          table.insert(deps, { id = dep_id, version = get_attr(attrs, "version") })
        end
      end
      table.sort(deps, function(a, b)
        return a.id < b.id
      end)
      cb(deps)
    end)
  end)
  if not ok then
    cb(nil)
  end
end

--- Matches nuget.org's own package page convention (confirmed live from a
--- screenshot): a plain minimum version shows as "Id (>= version)"; a nuspec
--- `version` attribute can rarely already be a full range expression like
--- "[1.0.0,2.0.0)" instead of a bare minimum -- shown as-is in that case
--- rather than wrapping something that isn't a bare version in ">= (...)".
---@param dep { id: string, version: string? }
---@return string
local function format_dependency_constraint(dep)
  if not dep.version or dep.version == "" then
    return dep.id
  end
  if dep.version:match("^[%[%(]") then
    return dep.id .. " " .. dep.version
  end
  return dep.id .. " (>= " .. dep.version .. ")"
end

--- The buffer we set here is a snapshot copy inside neo-tree's floating
--- preview (see preview.lua's setBuffer -- it copies lines in rather than
--- displaying this buffer directly), so it needs an explicit Preview.show()
--- refresh to actually become visible -- but only if the user is still
--- looking at this same package, not whatever they've moved on to since the
--- fetch (there are now two of these in flight per package: the main NuGet
--- search, and the separate nuget.org dependency lookup below).
---@param state table
---@param name string package name the fetch that just resolved was for
local function refresh_package_preview_if_focused(state, name)
  local Preview = require("neo-tree.sources.common.preview")
  if not Preview.is_active() then
    return
  end
  local current = state.tree:get_node()
  if current and current.extra and current.extra.dotnet_kind == "package" and current.extra.package_name == name then
    Preview.show(state)
  end
end

---@param node neotree_dotnet.Node
---@param state table
---@return integer bufnr
local function ensure_package_preview_buf(node, state)
  local name = node.extra.package_name
  local bufnr = package_preview_bufs[name]
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].buftype = "nofile"
    package_preview_bufs[name] = bufnr
  end

  local cached = package_details_cache[name]
  if cached == "pending" then
    return bufnr
  elseif cached then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, cached.lines)
    return bufnr
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Fetching details for " .. name .. " from NuGet..." })
  package_details_cache[name] = "pending"

  local client = require("easy-dotnet.rpc.rpc").global_rpc_client
  client:initialize(function()
    client.nuget:nuget_search(name, nil, function(results)
      local match
      for _, pkg in ipairs(results or {}) do
        if pkg.id:lower() == name:lower() then
          match = pkg
          break
        end
      end

      local lines, rows
      if match then
        lines, rows = format_package_details(node, match)
      else
        lines, rows = { "No NuGet metadata found for " .. name .. "." }, {}
      end
      package_details_cache[name] = { lines = lines, rows = rows }
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      refresh_package_preview_if_focused(state, name)

      local from_nuget_org = match and match.source and match.source:lower():find("nuget.org", 1, true) ~= nil
      if match and from_nuget_org then
        fetch_nuget_dependencies(match.id, match.version, function(deps)
          if not (deps and #deps > 0) then
            return -- private/internal feed, network failure, or genuinely no deps -- leave the preview as-is
          end
          local current_cache = package_details_cache[name]
          if type(current_cache) ~= "table" then
            return -- e.g. the buffer got torn down or recached in the meantime
          end
          table.insert(current_cache.lines, "")
          table.insert(current_cache.lines, "Dependencies:")
          table.insert(current_cache.rows, { first = #current_cache.lines, last = #current_cache.lines, kind = nil })
          local dep_lines_first = #current_cache.lines + 1
          local dep_id_end = {}
          for _, dep in ipairs(deps) do
            table.insert(current_cache.lines, "  " .. format_dependency_constraint(dep))
            dep_id_end[#current_cache.lines] = 2 + #dep.id -- 2 for the leading indent
          end
          current_cache.dependency_lines = { first = dep_lines_first, last = #current_cache.lines, id_end = dep_id_end }
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, current_cache.lines)
          refresh_package_preview_if_focused(state, name)
        end)
      end
    end)
  end)

  return bufnr
end

--- Patching the *command* (toggle_preview) isn't enough on its own: once a
--- preview is open, neo-tree's preview.lua registers its own VIM_CURSOR_MOVED
--- handler (inside Preview.toggle) that calls Preview.show(state) directly
--- on every cursor move, to keep the preview in sync as you navigate the
--- tree -- entirely bypassing whatever command is bound to 'p' (confirmed
--- live: preview only ever showed real package details right after pressing
--- 'p', not when moving to a different package afterward while a preview
--- was already open -- it kept falling back to the previous node's content/
--- the shared .csproj). Patch Preview.show itself instead, once, so both
--- entry points (the initial keypress *and* every subsequent cursor-move
--- auto-refresh) go through it. This is safe to leave patched permanently
--- for the whole session, unlike wrap_picker_handler's temporary per-command
--- wrap/unwrap above: Preview.show is a stable, always-available function,
--- not a one-shot RPC callback, and the dotnet_kind == "package" guard means
--- it's a pure no-op for every other neo-tree source's nodes (they never
--- have that field). Patching the *module table's* field, not a captured
--- reference, is what makes this work at all: neo-tree's own internal calls
--- (`Preview.show(state)` inside preview.lua) do a plain field lookup on
--- that same local `Preview` table on every call -- since `require(...)`
--- returns that identical table object, reassigning this field from outside
--- is visible to those internal calls too. (Contrast wrap_picker_handler's
--- comment above: that had to patch one layer deeper specifically because
--- rpc-client.lua's dispatch table captures a function *value* once, not a
--- live field lookup -- Preview.toggle/show have no such captured-copy step.)
--- The label/title highlighting has to be applied here, not inside
--- format_package_details/ensure_package_preview_buf above, because
--- extmarks don't survive the trip: neo-tree's floating preview shows a
--- *copy* of our buffer's lines inside its own internally-created scratch
--- buffer (setBuffer's float branch copies text via nvim_buf_get/set_lines
--- -- confirmed by reading it directly), and extmarks are buffer-local
--- metadata, not part of the copied text, so anything set on our own source
--- buffer (node.extra.bufnr) would simply never appear in the window the
--- user actually sees.
---
--- Reach into that real internal buffer directly instead. neo-tree's
--- preview.lua never exposes it any other way (`instance` is a private
--- local, not on the returned module table) except indirectly through
--- Preview.focus(), which internally does `vim.fn.win_gotoid(instance.winid)`
--- -- call it, read whatever window became current, then immediately
--- restore focus so this is invisible to the user (doesn't move the real
--- cursor, doesn't fire CursorMoved, so it doesn't re-trigger the
--- auto-refresh handler this whole thing lives next to).
---@return integer? bufnr
---@return integer? winid
local function real_preview_buf()
  local Preview = require("neo-tree.sources.common.preview")
  if not Preview.is_active() then
    return nil
  end
  local before = vim.api.nvim_get_current_win()
  Preview.focus()
  local winid = vim.api.nvim_get_current_win()
  if winid == before then
    return nil
  end
  local bufnr = vim.api.nvim_win_get_buf(winid)
  vim.api.nvim_set_current_win(before)
  return bufnr, winid
end

--- Neither of the other two highlighting mechanisms in play here can be
--- trusted for this: (1) neo-tree's own setBuffer starts a treesitter parser
--- on `self.bufnr` matching whatever filetype our *source* buffer has (none,
--- deliberately -- see the module comment above), so it does nothing on its
--- own; but (2) `self.bufnr` is the *same* persistent scratch buffer reused
--- across every preview while the float stays open, and once some other
--- preview attaches a REAL language's parser to it (e.g. previewing a .cs
--- file first attaches `c_sharp`), that parser doesn't get detached just
--- because a later preview's content doesn't match it -- confirmed live: a
--- package preview shown right after a .cs file preview got its numbers and
--- URLs colored, purely because C#'s grammar happened to parse "6.5.0" as
--- float literals and "https://..." as starting a `//` line comment. Looked
--- nice by coincidence for that specific text shape, but it's not ours, not
--- reliable (varies with whatever was last previewed), and not even
--- correct (a description containing literal "/*" would silently "comment
--- out" everything after it). So highlight deliberately and consistently
--- ourselves instead, every time, via our own extmarks in our own
--- namespace -- same pattern as the bold labels already use.
---@param bufnr integer the real internal preview buffer, from real_preview_buf()
---@param winid integer the real internal preview window, from real_preview_buf()
---@param cached { lines: string[], rows: neotree_dotnet.PreviewRow[], dependency_lines: { first: integer, last: integer, id_end: table<integer,integer> }? }
local function highlight_package_preview(bufnr, winid, cached)
  -- 'wrap' is on by default with 'linebreak' off, which breaks strictly at
  -- the window edge -- including mid-word (confirmed live: "IMemoryCache"
  -- split across two lines). 'linebreak' wraps at word boundaries instead,
  -- without changing the buffer's actual text.
  vim.wo[winid].linebreak = true

  vim.api.nvim_buf_clear_namespace(bufnr, PREVIEW_NS, 0, -1)
  if #cached.lines == 0 then
    return
  end
  vim.api.nvim_buf_set_extmark(bufnr, PREVIEW_NS, 0, 0, {
    end_row = 1,
    end_col = 0,
    hl_group = "NeotreeDotnetPreviewTitle",
  })

  local value_hl_groups = { number = "NeotreeDotnetPreviewNumber", url = "NeotreeDotnetPreviewUrl" }
  for _, r in ipairs(cached.rows) do
    local first_text = cached.lines[r.first]
    local colon = first_text:find(":")
    if colon then
      vim.api.nvim_buf_set_extmark(bufnr, PREVIEW_NS, r.first - 1, 0, {
        end_col = colon,
        hl_group = "NeotreeDotnetPreviewLabel",
      })
    end

    local value_hl = r.kind and value_hl_groups[r.kind]
    if value_hl then
      -- VALUE_COLUMN is where the value starts on every line in this row's
      -- range, first line or wrapped continuation alike -- that's the whole
      -- point of format_row_wrapped's alignment scheme.
      for line = r.first, r.last do
        local text = cached.lines[line]
        if #text > VALUE_COLUMN then
          vim.api.nvim_buf_set_extmark(bufnr, PREVIEW_NS, line - 1, VALUE_COLUMN, {
            end_row = line - 1,
            end_col = #text,
            hl_group = value_hl,
          })
        end
      end
    end
  end

  -- Dependency list entries ("  Id (>= version)") aren't "Label: value" rows
  -- at all -- see the append site in ensure_package_preview_buf -- so they
  -- aren't in `cached.rows`. Two spans per line: the package id gets the
  -- same namespace-reference color as the label rows above, and its version
  -- constraint gets the same Number color the top Installed/Latest/Downloads
  -- rows use -- even though it isn't strictly numeric (a pre-release suffix
  -- like "-beta1", or an exact range like "[1.0.0,2.0.0)", are still
  -- "version-shaped" text that reads naturally with the same styling as the
  -- other version numbers in this preview, explicit user request). id_end
  -- (computed alongside the formatted text, not re-derived by scanning for
  -- e.g. the first space or paren -- a package id can itself validly
  -- contain either) marks exactly where the id ends and the constraint
  -- (if any -- some dependencies have none) begins.
  if cached.dependency_lines then
    for line = cached.dependency_lines.first, cached.dependency_lines.last do
      local text = cached.lines[line]
      local id_end = cached.dependency_lines.id_end[line]
      if text and id_end and id_end > 2 then
        vim.api.nvim_buf_set_extmark(bufnr, PREVIEW_NS, line - 1, 2, {
          end_row = line - 1,
          end_col = id_end,
          hl_group = "NeotreeDotnetPreviewNamespace",
        })
      end
      if text and id_end and #text > id_end then
        vim.api.nvim_buf_set_extmark(bufnr, PREVIEW_NS, line - 1, id_end, {
          end_row = line - 1,
          end_col = #text,
          hl_group = "NeotreeDotnetPreviewNumber",
        })
      end
    end
  end
end

local preview = require("neo-tree.sources.common.preview")
local orig_preview_show = preview.show
preview.show = function(state)
  local node = state.tree:get_node()
  local is_package = node and node.extra and node.extra.dotnet_kind == "package"
  if is_package then
    node.extra.bufnr = ensure_package_preview_buf(node, state)
  end
  orig_preview_show(state)
  if is_package then
    local real_buf, real_win = real_preview_buf()
    if real_buf then
      -- Undo whatever an *earlier* preview in this same float session might
      -- have attached (see highlight_package_preview's doc comment) --
      -- neo-tree's own setBuffer never does this itself, since it has no
      -- reason to expect a buffer's language to change out from under it.
      -- Without this, a stale parser doesn't just sit there unused: it
      -- keeps actively highlighting our new content through the *previous*
      -- preview's grammar until something explicitly stops it.
      pcall(vim.treesitter.stop, real_buf)
    end
    local cached = package_details_cache[node.extra.package_name]
    if real_buf and real_win and type(cached) == "table" then
      highlight_package_preview(real_buf, real_win, cached)
    end
  end
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
