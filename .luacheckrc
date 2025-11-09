-- Luacheck configuration for Neovim plugin development

-- Define Neovim global variables
globals = {
  "vim",
}

-- Read-only globals (standard Lua)
read_globals = {
  "string",
  "table",
  "pairs",
  "ipairs",
  "require",
}

-- Ignore certain warnings
ignore = {
  "212", -- Unused argument (common in callback functions)
}

-- Maximum line length
max_line_length = 120
