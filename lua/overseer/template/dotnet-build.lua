local csproj_file = require("util.csharp-tools").get_csproj_file()


return {
  name = "dotnet_build",
  builder = function()

    print("building with overseer")

      -- Full path to current file (see :help expand())
    return {
      cmd = { "dotnet" },
      --/nologo & /clp:NoSummary are to prevent duplicate error lines
      --being returned and parsed
      args = { "build", csproj_file, "/nologo", "/clp:NoSummary" },
      components = {
          --automatically show quickfix 
          {"on_output_quickfix", open = true },
          --parse the output from the compile job using the default paser for .net
          {"on_output_parse", problem_matcher = "$msCompile"},
          -- "on_result_diagnostics",
          "on_result_diagnostics_quickfix",
          "default" },
    }
  end,
  condition = {
    filetype = { "cs" },
  },
}
