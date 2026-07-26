local M = {}

local config = require("aperture.config")
local core = require("aperture.core")
local highlight = require("aperture.highlight")

-- Run with :checkhealth aperture
function M.check()
  vim.health.start("aperture.nvim")

  -- Neovim version: nvim_get_hl(0, { name = ... }) requires 0.9+.
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.error("Neovim 0.9+ is required (uses the nvim_get_hl API)")
  end

  -- termguicolors: dimming sets true-color hex highlights that only render
  -- when this is on.
  if vim.o.termguicolors then
    vim.health.ok("'termguicolors' is enabled")
  else
    vim.health.warn(
      "'termguicolors' is off; dimming will not render",
      "Add `vim.o.termguicolors = true` to your config"
    )
  end

  -- setup(): options is empty until the user (or a plugin manager) calls it.
  if next(config.options) == nil then
    vim.health.warn(
      "setup() has not been called",
      "Call require('aperture').setup() to configure the plugin"
    )
    return
  end
  vim.health.ok("setup() has been called")

  -- Current feature state.
  vim.health.info(string.format("Dimming: %s", core.enabled and "enabled" or "disabled"))
  vim.health.info(
    string.format("Autosize: %s", config.options.autosize.enabled and "enabled" or "disabled")
  )

  -- Highlight capture: if dimming is on but nothing was captured, something is
  -- wrong (no colorscheme, all groups excluded, etc.).
  if core.enabled then
    local stats = highlight.get_highlight_stats()
    if stats.total > 0 then
      vim.health.ok(string.format("Captured %d highlight groups for dimming", stats.total))
    else
      vim.health.warn("No highlight groups were captured for dimming")
    end
  end
end

return M
