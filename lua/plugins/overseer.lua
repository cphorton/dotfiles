return {

  'stevearc/overseer.nvim',
  config = true,
  event = "VeryLazy",
  opts = {
    templates = {"dotnet"},
    --enable dap integration
    --this provides a preLaunchTask option to the dap configuration
    --the preLaunchTask takes a string for the name of the overseer task
    dap = true
  },

}
