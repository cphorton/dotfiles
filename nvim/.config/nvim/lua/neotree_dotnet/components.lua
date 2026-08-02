-- Node types stay "directory"/"file" (see lib/solution.lua) so every renderer
-- and command from neo-tree.sources.common works unmodified. The only thing
-- worth a custom look is the icon: swap it for the dotnet-specific nodes,
-- identified via node.extra.dotnet_kind, and fall through to the normal
-- folder/file icon everywhere else.
--
-- Solution/project nodes are real files (.sln/.slnx/.csproj) that just happen
-- to be rendered as "directory" for expand/collapse, so nvim-web-devicons
-- already has the right icon+color for them (it keys off node.name/csproj_name,
-- not node.type) -- reuse that instead of picking our own glyphs, so this
-- automatically follows whatever icon theme the user has configured. The
-- Dependencies/Packages/Projects grouping nodes have no real file behind them,
-- so those still need hand-picked glyphs.
local common = require("neo-tree.sources.common.components")

local M = {}

local static_icons = {
  dependencies = { text = "󰇙 ", highlight = "NeoTreeDirectoryIcon" },
  packages_group = { text = "󰏖 ", highlight = "NeoTreeDirectoryIcon" },
  projects_group = { text = "󰆧 ", highlight = "NeoTreeDirectoryIcon" },
  package = { text = "󰏗 ", highlight = "NeoTreeFileIcon" },
}

---@param filename string a real filename to resolve via nvim-web-devicons, e.g. "App.csproj"
---@param fallback string glyph to use if nvim-web-devicons isn't installed
local function devicon(filename, fallback)
  local ok, web_devicons = pcall(require, "nvim-web-devicons")
  if ok then
    local icon, hl = web_devicons.get_icon(filename)
    if icon then
      return { text = icon .. " ", highlight = hl or "NeoTreeFileIcon" }
    end
  end
  return { text = fallback .. " ", highlight = "NeoTreeFileIcon" }
end

M.icon = function(config, node, state)
  local kind = node.extra and node.extra.dotnet_kind
  if kind == "solution" then
    return devicon(node.name, "")
  elseif kind == "project" then
    return devicon(node.extra.csproj_name, "󰪮")
  elseif kind == "project_ref" then
    -- a reference to another project -- same "this is a project" icon as above
    return devicon(node.name .. ".csproj", "󰪮")
  elseif static_icons[kind] then
    return static_icons[kind]
  end
  return common.icon(config, node, state)
end

-- A package leaf's node.path is its *owning project's* .csproj (see
-- lib/solution.lua -- there's no file that "is" the package itself), so
-- last_modified/created correctly reflect that project file, but file_size
-- doesn't mean anything there. common.file_size already renders "-" for any
-- non-"file" node, so borrow that behavior via a proxy that only overrides
-- `type` -- reuses its exact padding/highlight instead of duplicating it.
M.file_size = function(config, node, state)
  if node.extra and node.extra.dotnet_kind == "package" then
    local as_directory = setmetatable({ type = "directory" }, { __index = node })
    return common.file_size(config, as_directory, state)
  end
  return common.file_size(config, node, state)
end

-- Same root cause as file_size above: git_status/diagnostics/modified/bufnr/
-- clipboard all key off node.path or node:get_id(), which for a package leaf
-- is the shared owning .csproj -- so every package under one project would
-- show that csproj's identical git/diagnostic/modified state repeated down
-- the whole list, which reads as per-package status but isn't. Unlike
-- file_size these don't reserve column width when empty (a clean file with
-- no git changes already renders nothing there), so returning {} is the
-- normal "nothing to show" result, not a special case.
for _, name in ipairs({ "git_status", "diagnostics", "modified", "bufnr", "clipboard" }) do
  local original = common[name]
  M[name] = function(config, node, state)
    if node.extra and node.extra.dotnet_kind == "package" then
      return {}
    end
    return original(config, node, state)
  end
end

return vim.tbl_deep_extend("force", common, M)
