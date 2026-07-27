local M = {}

-- Load config module
local config = require('aperture.config')
local core = require('aperture.core')

-- Setup function (called by user)
function M.setup(opts)
  -- Merge user options with defaults and validate
  local ok = config.setup(opts)
  if not ok then
    return false  -- Validation failed, error already shown
  end

  -- Enable dimming if configured. Silent: startup should not emit an info
  -- notification (users opt into feedback via the :Aperture* commands).
  if config.options.enabled then
    core.enable({ silent = true })
  end

  -- Initialize autosize if configured (even if dimming is disabled)
  core.init_autosize()

  return true
end

-- Enable dimming
function M.enable(opts)
  core.enable(opts)
end

-- Disable dimming
function M.disable(opts)
  core.disable(opts)
end

-- Toggle dimming
function M.toggle(opts)
  core.toggle(opts)
end

-- Refresh dimming (useful after config changes)
function M.refresh()
  core.refresh()
end

-- Check if dimming is enabled
function M.is_enabled()
  return core.enabled
end

-- Get diagnostic information about highlights
function M.get_stats()
  local highlight = require('aperture.highlight')
  local stats = highlight.get_highlight_stats()
  return stats
end

-- Print diagnostic information (for debugging)
function M.print_stats()
  local stats = M.get_stats()
  local lines = {
    "Aperture Highlight Statistics:",
    string.format("  Total groups captured: %d", stats.total),
    string.format("  Groups with foreground: %d", stats.with_fg),
    string.format("  Groups with background: %d", stats.with_bg),
    string.format("  Groups with special: %d", stats.with_sp),
    string.format("  Groups with attrs only: %d", stats.with_attrs_only),
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
