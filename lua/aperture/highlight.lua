local M = {}

-- Highlight groups that should have their background overridden
local BACKGROUND_GROUPS = {
  "Normal",
  "NormalNC",
  "EndOfBuffer",
}

-- Check if a highlight group should have background override applied
local function should_override_background(group_name)
  for _, name in ipairs(BACKGROUND_GROUPS) do
    if group_name == name then
      return true
    end
  end
  return false
end

-- Parse hex color to RGB components
function M.hex_to_rgb(hex)
  if not hex or hex == "" or hex == "NONE" then
    return nil
  end

  -- Remove # if present
  hex = hex:gsub("#", "")

  -- Handle 6-digit hex
  if #hex == 6 then
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    return r, g, b
  end

  return nil
end

-- Convert RGB to hex color
function M.rgb_to_hex(r, g, b)
  -- Clamp values to 0-255
  r = math.max(0, math.min(255, math.floor(r + 0.5)))
  g = math.max(0, math.min(255, math.floor(g + 0.5)))
  b = math.max(0, math.min(255, math.floor(b + 0.5)))

  return string.format("#%02x%02x%02x", r, g, b)
end

-- Apply dimming to RGB values
function M.apply_dim(r, g, b, amount)
  return r * (1 - amount), g * (1 - amount), b * (1 - amount)
end

-- Convert RGB to greyscale using luminosity method
function M.apply_greyscale(r, g, b, factor)
  local grey = 0.299 * r + 0.587 * g + 0.114 * b

  -- Interpolate between original and greyscale
  r = r * (1 - factor) + grey * factor
  g = g * (1 - factor) + grey * factor
  b = b * (1 - factor) + grey * factor

  return r, g, b
end

-- Apply sepia tone effect
function M.apply_sepia(r, g, b, factor)
  local tr = 0.393 * r + 0.769 * g + 0.189 * b
  local tg = 0.349 * r + 0.686 * g + 0.168 * b
  local tb = 0.272 * r + 0.534 * g + 0.131 * b

  -- Interpolate between original and sepia
  r = r * (1 - factor) + tr * factor
  g = g * (1 - factor) + tg * factor
  b = b * (1 - factor) + tb * factor

  return r, g, b
end

-- Apply all color transformations
function M.transform_color(hex, dim_amount, greyscale_factor, sepia_factor)
  local r, g, b = M.hex_to_rgb(hex)

  if not r then
    return nil
  end

  -- Apply effects in order: dim, greyscale, sepia
  if dim_amount > 0 then
    r, g, b = M.apply_dim(r, g, b, dim_amount)
  end

  if greyscale_factor > 0 then
    r, g, b = M.apply_greyscale(r, g, b, greyscale_factor)
  end

  if sepia_factor > 0 then
    r, g, b = M.apply_sepia(r, g, b, sepia_factor)
  end

  return M.rgb_to_hex(r, g, b)
end

-- Get highlight group definition
function M.get_highlight(group_name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group_name, link = false })
  if not ok then
    return nil
  end
  return hl
end

-- Transform a highlight group with given effects
function M.transform_highlight(hl, dim_amount, greyscale_factor, sepia_factor)
  if not hl then
    return nil
  end

  local new_hl = vim.deepcopy(hl)

  -- Transform foreground color
  if hl.fg then
    local fg_hex = string.format("#%06x", hl.fg)
    local new_fg = M.transform_color(fg_hex, dim_amount, greyscale_factor, sepia_factor)
    if new_fg then
      new_hl.fg = new_fg
    end
  end

  -- Transform background color
  if hl.bg then
    local bg_hex = string.format("#%06x", hl.bg)
    local new_bg = M.transform_color(bg_hex, dim_amount, greyscale_factor, sepia_factor)
    if new_bg then
      new_hl.bg = new_bg
    end
  end

  -- Transform special colors (undercurl, etc.)
  if hl.sp then
    local sp_hex = string.format("#%06x", hl.sp)
    local new_sp = M.transform_color(sp_hex, dim_amount, greyscale_factor, sepia_factor)
    if new_sp then
      new_hl.sp = new_sp
    end
  end

  return new_hl
end

-- Apply background color override for specific highlight groups
-- This is useful for transparent colorschemes or to create stronger contrast
function M.apply_background_override(hl, group_name, dim_background)
  if not dim_background or not hl then
    return hl
  end

  if should_override_background(group_name) then
    local new_hl = vim.deepcopy(hl)
    new_hl.bg = dim_background
    return new_hl
  end

  return hl
end

-- Get all highlight groups
function M.get_all_highlights()
  local highlights = {}
  local all_groups = vim.fn.getcompletion("", "highlight")

  for _, group_name in ipairs(all_groups) do
    local hl = M.get_highlight(group_name)
    -- Include groups even without colors - they might have other attributes
    -- or be needed for inheritance chains
    if hl and (hl.fg or hl.bg or hl.sp or hl.bold or hl.italic or hl.underline) then
      highlights[group_name] = hl
    end
  end

  return highlights
end

-- Get count of all highlight groups (for diagnostics)
function M.get_highlight_count()
  local all_groups = vim.fn.getcompletion("", "highlight")
  return #all_groups
end

-- Get detailed statistics about highlights (for debugging)
function M.get_highlight_stats()
  local all_highlights = M.get_all_highlights()
  local stats = {
    total = 0,
    with_fg = 0,
    with_bg = 0,
    with_sp = 0,
    with_attrs_only = 0,
  }

  for _, hl in pairs(all_highlights) do
    stats.total = stats.total + 1
    if hl.fg then stats.with_fg = stats.with_fg + 1 end
    if hl.bg then stats.with_bg = stats.with_bg + 1 end
    if hl.sp then stats.with_sp = stats.with_sp + 1 end
    if not (hl.fg or hl.bg or hl.sp) then
      stats.with_attrs_only = stats.with_attrs_only + 1
    end
  end

  return stats
end

return M
