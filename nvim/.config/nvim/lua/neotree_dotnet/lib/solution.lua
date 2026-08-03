-- Builds a solution/project/file tree for the neotree_dotnet source.
-- Deliberately dependency-free from neo-tree itself: it returns plain nested
-- tables ({id, name, path, type, children, extra}) that init.lua hands to
-- neo-tree's renderer.show_nodes(), so this half can be tested/reused on its own.

local uv = vim.uv or vim.loop
local M = {}

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

--- Parses `Project("{TypeGuid}") = "Name", "RelPath.csproj", "{Guid}"` lines out
--- of a classic .sln file. Solution folders and non-C# projects (fsproj,
--- vcxproj, ...) are skipped -- this is scoped to C# projects only, per
--- easy-dotnet's focus.
---@param sln_dir string absolute directory the solution file lives in
---@param content string raw .sln file contents
---@return { name: string, path: string }[]
local function parse_projects_sln(sln_dir, content)
  local projects = {}
  for name, rel_path in content:gmatch('Project%("{[^}]+}"%)%s*=%s*"([^"]+)"%s*,%s*"([^"]+)"') do
    if rel_path:match("%.csproj$") then
      -- .sln files always use backslash separators for the relative path,
      -- even when the solution lives on Linux/macOS -- normalize before joining.
      local abs_path = vim.fs.normalize(vim.fs.joinpath(sln_dir, (rel_path:gsub("\\", "/"))))
      table.insert(projects, { name = name, path = abs_path })
    end
  end
  return projects
end

--- Parses `<Project Path="RelPath.csproj" />` elements out of the newer XML
--- .slnx format (VS 2022 17.13+ / .NET 9 SDK). Unlike .sln, it doesn't carry
--- an explicit display name or per-project GUID, and folders are just for
--- grouping in the UI -- <Project> entries are matched regardless of which
--- <Folder> they're nested under, so the folder structure itself is dropped.
---@param sln_dir string absolute directory the solution file lives in
---@param content string raw .slnx file contents
---@return { name: string, path: string }[]
local function parse_projects_slnx(sln_dir, content)
  local projects = {}
  for rel_path in content:gmatch('<Project%s+Path="([^"]+)"') do
    if rel_path:match("%.csproj$") then
      local abs_path = vim.fs.normalize(vim.fs.joinpath(sln_dir, (rel_path:gsub("\\", "/"))))
      local name = vim.fs.basename(rel_path):gsub("%.csproj$", "")
      table.insert(projects, { name = name, path = abs_path })
    end
  end
  return projects
end

---@param sln_path string absolute path to the .sln or .slnx file
---@return { name: string, path: string }[]
function M.parse_projects(sln_path)
  local content = read_file(sln_path)
  if not content then
    return {}
  end
  local sln_dir = vim.fs.dirname(sln_path)
  if sln_path:match("%.slnx$") then
    return parse_projects_slnx(sln_dir, content)
  end
  return parse_projects_sln(sln_dir, content)
end

---@class neotree_dotnet.Node
---@field id string
---@field name string
---@field path string
---@field type "directory"|"file"
---@field children neotree_dotnet.Node[]
---@field extra? { dotnet_kind: "solution"|"project"|"dependencies"|"packages_group"|"projects_group"|"package"|"project_ref", csproj_name?: string, package_name?: string, installed_version?: string }

--- Pulls attributes out of a single tag's opening `<Tag ...>` (self-closing or
--- not) without needing a real XML parser -- fine for the well-formed,
--- SDK-generated csproj files this targets.
---@param attrs string raw attribute text between the tag name and its closing `>`
---@param attr_name string
---@return string?
local function get_attr(attrs, attr_name)
  return attrs:match(attr_name .. '%s*=%s*"([^"]*)"')
end

--- Central Package Management (Directory.Packages.props) lets a repo pin
--- <PackageReference> versions in one place instead of every csproj, in which
--- case the csproj's own PackageReference has no Version attribute at all.
--- Walk upward from the solution directory (the conventional location) to
--- pick up its <PackageVersion Include="X" Version="Y" /> entries, if any.
---@param start_dir string
---@return table<string, string> name -> version
local function find_central_package_versions(start_dir)
  local versions = {}
  local props_path = vim.fs.find("Directory.Packages.props", { path = start_dir, upward = true, type = "file" })[1]
  local content = props_path and read_file(props_path)
  if not content then
    return versions
  end
  for attrs in content:gmatch("<PackageVersion%s+(.-)%s*/?>") do
    local name = get_attr(attrs, "Include")
    local version = get_attr(attrs, "Version")
    if name and version then
      versions[name] = version
    end
  end
  return versions
end

--- Parses `<PackageReference Include="Name" Version="X" />` out of a csproj.
--- Falls back to `cpm_versions` (from Directory.Packages.props) when the
--- Version attribute is absent, which is how Central Package Management repos
--- write PackageReference. A reference that resolves neither way is still
--- listed, just without a version.
---@param csproj_path string
---@param cpm_versions table<string, string>
---@return { name: string, version: string? }[]
local function parse_package_references(csproj_path, cpm_versions)
  local content = read_file(csproj_path)
  if not content then
    return {}
  end
  local packages = {}
  for attrs in content:gmatch("<PackageReference%s+(.-)%s*/?>") do
    local name = get_attr(attrs, "Include")
    if name then
      local version = get_attr(attrs, "Version") or cpm_versions[name]
      table.insert(packages, { name = name, version = version })
    end
  end
  table.sort(packages, function(a, b)
    return a.name < b.name
  end)
  return packages
end

--- Parses `<ProjectReference Include="../Other/Other.csproj" />` out of a
--- csproj, resolving each to an absolute path (again normalizing the
--- backslash separators MSBuild always writes, same as the .sln parsing above).
---@param csproj_path string
---@return { name: string, path: string }[]
local function parse_project_references(csproj_path)
  local content = read_file(csproj_path)
  if not content then
    return {}
  end
  local dir = vim.fs.dirname(csproj_path)
  local refs = {}
  for attrs in content:gmatch("<ProjectReference%s+(.-)%s*/?>") do
    local rel_path = get_attr(attrs, "Include")
    if rel_path then
      local abs_path = vim.fs.normalize(vim.fs.joinpath(dir, (rel_path:gsub("\\", "/"))))
      local name = vim.fs.basename(abs_path):gsub("%.csproj$", "")
      table.insert(refs, { name = name, path = abs_path })
    end
  end
  table.sort(refs, function(a, b)
    return a.name < b.name
  end)
  return refs
end

--- Builds the VS-style "Dependencies" node for a project: a "Packages" group
--- (NuGet PackageReferences) and a "Projects" group (ProjectReferences),
--- whichever aren't empty. Returns nil if the project has neither, so empty
--- projects don't grow a permanently-empty Dependencies node.
---@param project { name: string, path: string }
---@param cpm_versions table<string, string>
---@return neotree_dotnet.Node?
local function build_dependencies_node(project, cpm_versions)
  local packages = parse_package_references(project.path, cpm_versions)
  local project_refs = parse_project_references(project.path)
  if #packages == 0 and #project_refs == 0 then
    return nil
  end

  local groups = {}
  if #packages > 0 then
    local package_nodes = {}
    for _, pkg in ipairs(packages) do
      local label = pkg.version and (pkg.name .. " (" .. pkg.version .. ")") or pkg.name
      table.insert(package_nodes, {
        id = project.path .. "!deps!pkg!" .. pkg.name,
        name = label,
        -- no on-disk representation for the package itself; point "open" at
        -- the csproj that references it, the closest useful thing to jump to
        path = project.path,
        type = "file",
        children = {},
        extra = { dotnet_kind = "package", package_name = pkg.name, installed_version = pkg.version },
      })
    end
    table.insert(groups, {
      id = project.path .. "!deps!packages",
      name = "Packages",
      path = project.path,
      type = "directory",
      children = package_nodes,
      extra = { dotnet_kind = "packages_group" },
    })
  end

  if #project_refs > 0 then
    local ref_nodes = {}
    for _, ref in ipairs(project_refs) do
      table.insert(ref_nodes, {
        id = project.path .. "!deps!projref!" .. ref.path,
        name = ref.name,
        path = ref.path, -- opening this jumps straight to the referenced .csproj
        type = "file",
        children = {},
        extra = { dotnet_kind = "project_ref" },
      })
    end
    table.insert(groups, {
      id = project.path .. "!deps!projects",
      name = "Projects",
      path = project.path,
      type = "directory",
      children = ref_nodes,
      extra = { dotnet_kind = "projects_group" },
    })
  end

  return {
    id = project.path .. "!deps",
    name = "Dependencies",
    path = project.path,
    type = "directory",
    children = groups,
    extra = { dotnet_kind = "dependencies" },
  }
end

--- Walks a project's directory for .cs files, skipping bin/obj/hidden dirs.
--- SDK-style csproj implicitly globs every .cs file under the project directory,
--- so this approximates it without parsing <Compile Remove> items. A project
--- whose directory contains another project's files (rare, but legal) will
--- double-list those files -- fine for a first pass, worth tightening later
--- by stopping descent at any directory containing its own .csproj.
---@param dir string absolute directory to scan
---@return neotree_dotnet.Node[]
local function scan_cs_files(dir)
  local nodes = {}
  local handle = uv.fs_scandir(dir)
  if not handle then
    return nodes
  end
  while true do
    local name, ftype = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    local abs = vim.fs.joinpath(dir, name)
    if ftype == "directory" then
      if name ~= "bin" and name ~= "obj" and name:sub(1, 1) ~= "." then
        local children = scan_cs_files(abs)
        if #children > 0 then
          table.insert(nodes, { id = abs, name = name, path = abs, type = "directory", children = children })
        end
      end
    elseif ftype == "file" and name:match("%.cs$") then
      table.insert(nodes, { id = abs, name = name, path = abs, type = "file", children = {} })
    end
  end
  table.sort(nodes, function(a, b)
    if a.type ~= b.type then
      return a.type == "directory"
    end
    return a.name < b.name
  end)
  return nodes
end

---@param project { name: string, path: string }
---@param cpm_versions table<string, string>
---@return neotree_dotnet.Node
function M.build_project_node(project, cpm_versions)
  local dir = vim.fs.dirname(project.path)
  local children = scan_cs_files(dir)
  local deps = build_dependencies_node(project, cpm_versions or {})
  if deps then
    table.insert(children, 1, deps)
  end
  return {
    id = project.path,
    name = project.name,
    path = dir,
    type = "directory",
    children = children,
    extra = { dotnet_kind = "project", csproj_name = vim.fs.basename(project.path) },
  }
end

--- Finds the .sln easy-dotnet already knows about (whatever the user last
--- selected via its picker), falling back to a plain glob under cwd so the
--- explorer still works before easy-dotnet has been asked to pick anything.
---@return string?
function M.find_solution()
  local ok, easy_dotnet = pcall(require, "easy-dotnet")
  if ok then
    local selected = easy_dotnet.try_get_selected_solution()
    if selected and selected.path then
      return selected.path
    end
  end
  local found = vim.fn.globpath(vim.fn.getcwd(), "*.sln", false, true)
  if #found == 0 then
    found = vim.fn.globpath(vim.fn.getcwd(), "*.slnx", false, true)
  end
  return found[1]
end

---@return neotree_dotnet.Node?
function M.build_tree()
  local sln_path = M.find_solution()
  if not sln_path then
    return nil
  end
  local sln_dir = vim.fs.dirname(sln_path)
  local cpm_versions = find_central_package_versions(sln_dir)
  local projects = {}
  for _, project in ipairs(M.parse_projects(sln_path)) do
    table.insert(projects, M.build_project_node(project, cpm_versions))
  end
  return {
    id = sln_path,
    name = vim.fs.basename(sln_path),
    path = sln_dir,
    type = "directory",
    children = projects,
    extra = { dotnet_kind = "solution" },
  }
end

return M
