-- A neo-tree source that shows the current .sln as a tree of C# projects and
-- their .cs files, instead of the raw filesystem. Registered as an external
-- source (see neo-tree docs: `sources` entries neo-tree doesn't recognize as
-- built-in are require()'d directly), so this only needs to live under
-- lua/neotree_dotnet -- no neo-tree.sources.* namespace needed.
--
-- Solution/project discovery is delegated to easy-dotnet.nvim (whatever
-- solution it has selected); see lib/solution.lua for the actual parsing.
-- Press 'R' (neo-tree's default refresh mapping) after switching solutions
-- or adding/removing files -- there's no filesystem watcher wired up yet.

local renderer = require("neo-tree.ui.renderer")
local events = require("neo-tree.events")
local manager = require("neo-tree.sources.manager")
local utils = require("neo-tree.utils")
local git = require("neo-tree.git")
local solution = require("neotree_dotnet.lib.solution")

---@class neotree.sources.Dotnet : neotree.Source
local M = {
  name = "dotnet",
  display_name = "  .NET ",
}

local wrap = function(func)
  return utils.wrap(func, M.name)
end

---@param state neotree.State
---@param path string?
---@param path_to_reveal string?
---@param callback function?
M.navigate = function(state, path, path_to_reveal, callback)
  local root = solution.build_tree()
  if not root then
    vim.notify("[neotree-dotnet] No .sln found for " .. vim.fn.getcwd(), vim.log.levels.WARN)
    renderer.show_nodes({}, state)
    return
  end

  -- git_status/diagnostics components resolve by real path underneath this
  -- root, and toggle_preview opens node.path directly -- both come for free
  -- once state.path points at the solution dir and the events below keep
  -- state.git_status_lookup / state.diagnostics_lookup populated.
  state.path = root.path

  state.default_expanded_nodes = { root.id }
  for _, project in ipairs(root.children) do
    table.insert(state.default_expanded_nodes, project.id)
  end

  renderer.show_nodes({ root }, state)

  if path_to_reveal then
    renderer.position.set(state, path_to_reveal)
  end
  if type(callback) == "function" then
    vim.schedule(callback)
  end
end

---@param config neotree.Config.Source
---@param global_config neotree.Config.Base
M.setup = function(config, global_config)
  if global_config.enable_git_status then
    manager.subscribe(M.name, {
      event = events.BEFORE_RENDER,
      ---@param state neotree.State
      handler = function(state)
        if state.path then
          git.status(state.path, state.git_base_by_worktree, false)
        end
      end,
    })
    manager.subscribe(M.name, {
      event = events.GIT_EVENT,
      handler = wrap(manager.refresh),
    })
  end

  if global_config.enable_diagnostics then
    manager.subscribe(M.name, {
      event = events.STATE_CREATED,
      handler = function(state)
        state.diagnostics_lookup = utils.get_diagnostic_counts()
      end,
    })
    manager.subscribe(M.name, {
      event = events.VIM_DIAGNOSTIC_CHANGED,
      handler = wrap(manager.diagnostics_changed),
    })
  end
end

return M
