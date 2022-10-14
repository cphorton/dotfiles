require('telescope').setup{
defaults = {
	--path_display = { shorten = 3 },
	path_display = { smart },
	file_ignore_patterns = { "node_modules", ".git", "bin", "obj", ".vs" }
  },
}
