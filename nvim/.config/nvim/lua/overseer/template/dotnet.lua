local tmpl = {
  name = "Build .NET App With Spinner",
  builder = function(params)

    if require("utils.dotnet").any_unsaved_buffers() then
        local choice = vim.fn.confirm(("Save changes before building"), "&Yes\n&No")
        if choice == 0 or choice == 3 then -- 0 for <Esc>/<C-c> and 3 for Cancel
          return
        end
        if choice == 1 then -- Yes
          vim.cmd "wa"
        end
    end

    local logPath = vim.fn.stdpath("data") .. "/easy-dotnet/build.log"
    function filter_warnings(line)
      if not line:find("warning") then
        return line:match("^(.+)%((%d+),(%d+)%)%: (.+)$")
      end
    end
    return {
      name = "build",
      cmd = "dotnet build /flp:v=q /flp:logfile=" .. logPath,
      components = {
        { "on_complete_dispose", timeout = 30 },
        "default",
        "show_spinner",
        { "unique", replace = true },
        {
          "on_output_parse",
          parser = {
            diagnostics = {
              { "extract", filter_warnings, "filename", "lnum", "col", "text" },
            },
          },
        },
        {
          "on_result_diagnostics_quickfix",
          open = true,
          close = true,
        },
      },
      cwd = require("easy-dotnet").get_debug_dll().relative_project_path,
    }
  end,
}
return tmpl

