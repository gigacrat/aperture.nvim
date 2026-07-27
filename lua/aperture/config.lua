local M = {}

-- Default options
M.defaults = {
  enabled = true,                    -- Enable dimming on startup
  dim_amount = 0.3,                  -- Amount to dim unfocused windows (0.0-1.0)
  greyscale_factor = 0.0,            -- Amount of greyscale effect (0.0-1.0)
  sepia_factor = 0.0,                -- Amount of sepia effect (0.0-1.0)
  dim_background = nil,              -- Optional: Override background color for dimmed windows (e.g., "#1a1a1a")
  debug = false,                     -- Enable debug logging
  quiet = false,                     -- Suppress :Aperture* enable/disable notifications (startup is always silent)

  -- Window autosize configuration
  autosize = {
    enabled = false,                 -- Enable automatic window resizing
    min_width = 80,                  -- Minimum width for active window (use 0-1 for percentage, >=1 for absolute columns)
    min_height = 20,                 -- Minimum height for active window (use 0-1 for percentage, >=1 for absolute rows)
  },

  -- Excluded filetypes and buffer types
  excluded_filetypes = {
    -- "NvimTree",
    -- "neo-tree",
    --"TelescopePreview",
    -- "lazy",
    -- "mason",
  },
  excluded_buftypes = {
    "prompt",  -- Interactive prompts (keep these undimmed)
    -- Note: "terminal" is NOT excluded by default so terminals will be dimmed
    -- Add "terminal" here if you want to exclude terminal windows from dimming
  },

  -- Highlight group patterns to exclude from dimming (Lua patterns)
  excluded_highlight_patterns = {
    "^WinSeparator",      -- Window separators
    -- "^Telescope",      -- Telescope UI (already handled by floating window exclusion)
    -- "Border$",         -- All border highlights (FloatBorder, etc.)
  },
}

-- Active options (populated by setup)
M.options = {}

-- List-like options that must be replaced wholesale rather than deep-merged.
-- vim.tbl_deep_extend merges arrays by index, so without this a user could not
-- shrink or clear a non-empty default list (e.g. excluded_buftypes = {}).
local LIST_OPTIONS = {
  "excluded_filetypes",
  "excluded_buftypes",
  "excluded_highlight_patterns",
}

-- Validate a hex color string
local function validate_hex_color(color)
  if type(color) ~= "string" then
    return false, "must be a string"
  end
  if not color:match("^#%x%x%x%x%x%x$") then
    return false, "must be a valid hex color (e.g., '#1a1a1a')"
  end
  return true
end

-- Validate configuration options
local function validate_options(opts)
  local errors = {}

  -- Validate numeric ranges
  if opts.dim_amount ~= nil then
    if type(opts.dim_amount) ~= "number" then
      table.insert(errors, "dim_amount must be a number")
    elseif opts.dim_amount < 0 or opts.dim_amount > 1 then
      table.insert(errors, "dim_amount must be between 0.0 and 1.0")
    end
  end

  if opts.greyscale_factor ~= nil then
    if type(opts.greyscale_factor) ~= "number" then
      table.insert(errors, "greyscale_factor must be a number")
    elseif opts.greyscale_factor < 0 or opts.greyscale_factor > 1 then
      table.insert(errors, "greyscale_factor must be between 0.0 and 1.0")
    end
  end

  if opts.sepia_factor ~= nil then
    if type(opts.sepia_factor) ~= "number" then
      table.insert(errors, "sepia_factor must be a number")
    elseif opts.sepia_factor < 0 or opts.sepia_factor > 1 then
      table.insert(errors, "sepia_factor must be between 0.0 and 1.0")
    end
  end

  -- Validate dim_background color
  if opts.dim_background ~= nil then
    local valid, err = validate_hex_color(opts.dim_background)
    if not valid then
      table.insert(errors, "dim_background " .. err)
    end
  end

  -- Validate boolean options
  if opts.enabled ~= nil and type(opts.enabled) ~= "boolean" then
    table.insert(errors, "enabled must be a boolean")
  end

  if opts.debug ~= nil and type(opts.debug) ~= "boolean" then
    table.insert(errors, "debug must be a boolean")
  end

  if opts.quiet ~= nil and type(opts.quiet) ~= "boolean" then
    table.insert(errors, "quiet must be a boolean")
  end

  -- Validate array options
  if opts.excluded_filetypes ~= nil and type(opts.excluded_filetypes) ~= "table" then
    table.insert(errors, "excluded_filetypes must be a table/array")
  end

  if opts.excluded_buftypes ~= nil and type(opts.excluded_buftypes) ~= "table" then
    table.insert(errors, "excluded_buftypes must be a table/array")
  end

  if opts.excluded_highlight_patterns ~= nil and type(opts.excluded_highlight_patterns) ~= "table" then
    table.insert(errors, "excluded_highlight_patterns must be a table/array")
  end

  -- Validate autosize options
  if opts.autosize ~= nil then
    if type(opts.autosize) ~= "table" then
      table.insert(errors, "autosize must be a table")
    else
      if opts.autosize.enabled ~= nil and type(opts.autosize.enabled) ~= "boolean" then
        table.insert(errors, "autosize.enabled must be a boolean")
      end

      if opts.autosize.min_width ~= nil then
        if type(opts.autosize.min_width) ~= "number" then
          table.insert(errors, "autosize.min_width must be a number")
        elseif opts.autosize.min_width <= 0 then
          table.insert(errors, "autosize.min_width must be greater than 0 (use 0-1 for percentage, >=1 for absolute)")
        end
      end

      if opts.autosize.min_height ~= nil then
        if type(opts.autosize.min_height) ~= "number" then
          table.insert(errors, "autosize.min_height must be a number")
        elseif opts.autosize.min_height <= 0 then
          table.insert(errors, "autosize.min_height must be greater than 0 (use 0-1 for percentage, >=1 for absolute)")
        end
      end
    end
  end

  return errors
end

function M.setup(opts)
  opts = opts or {}

  -- Validate options
  local errors = validate_options(opts)
  if #errors > 0 then
    local error_msg = "Aperture configuration errors:\n  - " .. table.concat(errors, "\n  - ")
    vim.notify(error_msg, vim.log.levels.ERROR)
    return false
  end

  -- Merge user opts into defaults
  M.options = vim.tbl_deep_extend('force', {}, M.defaults, opts)

  -- Replace list options wholesale so users can override a default list entirely
  -- (deep-extend would otherwise merge them element-by-element).
  for _, key in ipairs(LIST_OPTIONS) do
    if opts[key] ~= nil then
      M.options[key] = vim.deepcopy(opts[key])
    end
  end

  return true
end

-- Check if a window should be excluded from dimming
function M.should_exclude_window(winnr)
  -- Exclude floating windows (Telescope, LSP hover, code actions, etc.)
  local win_config = vim.api.nvim_win_get_config(winnr)
  if win_config.relative ~= "" then
    return true
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local filetype = vim.bo[bufnr].filetype
  local buftype = vim.bo[bufnr].buftype

  -- Check if filetype is excluded
  for _, ft in ipairs(M.options.excluded_filetypes) do
    if filetype == ft then
      return true
    end
  end

  -- Check if buftype is excluded
  for _, bt in ipairs(M.options.excluded_buftypes) do
    if buftype == bt then
      return true
    end
  end

  return false
end

return M
