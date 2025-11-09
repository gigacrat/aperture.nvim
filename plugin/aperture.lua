-- This file is auto-loaded after lazy loading completes

-- Prevent loading twice
if vim.g.loaded_aperture then
  return
end
vim.g.loaded_aperture = 1

-- Enable dimming
vim.api.nvim_create_user_command('ApertureEnable', function()
  require('aperture').enable()
end, {
  desc = "Enable window dimming for unfocused windows",
})

-- Disable dimming
vim.api.nvim_create_user_command('ApertureDisable', function()
  require('aperture').disable()
end, {
  desc = "Disable window dimming",
})

-- Toggle dimming
vim.api.nvim_create_user_command('ApertureToggle', function()
  require('aperture').toggle()
end, {
  desc = "Toggle window dimming on/off",
})

-- Refresh dimming
vim.api.nvim_create_user_command('ApertureRefresh', function()
  require('aperture').refresh()
end, {
  desc = "Refresh dimming highlights (useful after colorscheme change)",
})

-- Optional: Add a reload command for development
vim.api.nvim_create_user_command('ApertureReload', function()
  for name, _ in pairs(package.loaded) do
    if name:match('^aperture') then
      package.loaded[name] = nil
    end
  end
  require('aperture').setup()
  vim.notify("Aperture plugin reloaded!", vim.log.levels.INFO)
end, {
  desc = "Reload the Aperture plugin (development)",
})

-- Show diagnostic statistics
vim.api.nvim_create_user_command('ApertureStats', function()
  require('aperture').print_stats()
end, {
  desc = "Show diagnostic statistics about captured highlights",
})
