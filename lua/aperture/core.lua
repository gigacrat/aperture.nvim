local M = {}

-- State management
M.enabled = false
M.autocmd_group = nil
M.dim_namespace = nil
M.current_focus_win = nil
M.refresh_timer = nil
M.refresh_pending = false

local config = require('aperture.config')
local highlight = require('aperture.highlight')

-- Check if a highlight group should be excluded from dimming
local function should_exclude_highlight(group_name)
  for _, pattern in ipairs(config.options.excluded_highlight_patterns or {}) do
    if group_name:match(pattern) then
      return true
    end
  end
  return false
end

-- Internal refresh logic (shared by both debounced and immediate refresh)
local function do_refresh()
  local before_count = highlight.get_highlight_count()
  M.create_dimmed_highlights()
  local after_count = highlight.get_highlight_count()

  if config.options.debug then
    vim.notify(
      string.format("Aperture: Refreshed highlights (found %d groups)", after_count),
      vim.log.levels.DEBUG
    )
  end

  M.update_windows()
end

-- Debounced refresh to avoid excessive recomputation
-- This is called when new highlights might have been added (LSP attach, buffer load, etc.)
local function debounced_refresh()
  if M.refresh_pending then
    return
  end

  M.refresh_pending = true

  -- Only one timer is ever in flight at a time (guarded by refresh_pending).
  -- Clear our reference when it fires so disable() knows it's already done.
  M.refresh_timer = vim.defer_fn(function()
    M.refresh_pending = false
    M.refresh_timer = nil
    if M.enabled then
      do_refresh()
    end
  end, 100) -- 100ms debounce delay
end

-- Create dimmed versions of all highlight groups in the namespace
function M.create_dimmed_highlights()
  if not M.dim_namespace then
    M.dim_namespace = vim.api.nvim_create_namespace('aperture_dimming')
  end

  local dim_amount = config.options.dim_amount or config.defaults.dim_amount
  local greyscale_factor = config.options.greyscale_factor or config.defaults.greyscale_factor
  local sepia_factor = config.options.sepia_factor or config.defaults.sepia_factor
  local dim_background = config.options.dim_background

  -- Get all currently defined highlight groups
  local all_highlights = highlight.get_all_highlights()

  -- Transform each highlight group and define in namespace
  for group_name, hl in pairs(all_highlights) do
    -- Skip highlight groups that should never be dimmed
    if not should_exclude_highlight(group_name) then
      local dimmed_hl = highlight.transform_highlight(hl, dim_amount, greyscale_factor, sepia_factor)
      if dimmed_hl then
        -- Apply background override if configured (for transparent themes, etc.)
        dimmed_hl = highlight.apply_background_override(dimmed_hl, group_name, dim_background)

        -- Define the dimmed highlight in our namespace with the same name
        vim.api.nvim_set_hl(M.dim_namespace, group_name, dimmed_hl)
      end
    end
  end
end

-- Apply dimming to a window using namespace
function M.dim_window(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  if config.should_exclude_window(winnr) then
    return
  end

  if M.dim_namespace then
    vim.api.nvim_win_set_hl_ns(winnr, M.dim_namespace)
  end
end

-- Remove dimming from a window (restore default namespace)
function M.undim_window(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  vim.api.nvim_win_set_hl_ns(winnr, 0)
end

-- Helper function to collect all leaf window IDs from a layout tree
local function collect_leaf_windows(layout)
  local windows = {}

  local function traverse(node)
    if node[1] == "leaf" then
      table.insert(windows, node[2])
    elseif node[1] == "col" or node[1] == "row" then
      for _, child in ipairs(node[2]) do
        traverse(child)
      end
    end
  end

  traverse(layout)
  return windows
end

-- Helper function to get one representative window from a node
-- For leaf nodes: returns the window ID
-- For container nodes: returns the first leaf window in the subtree
local function get_representative_window(node)
  if node[1] == "leaf" then
    return node[2]
  else
    local leaves = collect_leaf_windows(node)
    return leaves[1]  -- Returns nil if no leaves found
  end
end

-- Helper function to find the container and siblings for a window in the layout tree
-- Returns: list of representative windows from each direct child of the matching container
-- For "row" containers: returns one window per vertical section (since they share width)
-- For "col" containers: returns one window per horizontal section (since they share height)
local function find_window_container(layout, target_win, container_type, debug)
  -- Returns: true if target window is in this subtree
  local function contains_window(node, win_id)
    if node[1] == "leaf" then
      return node[2] == win_id
    else
      for _, child in ipairs(node[2]) do
        if contains_window(child, win_id) then
          return true
        end
      end
    end
    return false
  end

  local function traverse(node, depth)
    depth = depth or 0
    if node[1] == "leaf" then
      return nil
    end

    local current_type = node[1]  -- "row" or "col"
    local children = node[2]

    if debug then
      vim.notify(string.format("  %sChecking %s container with %d children", string.rep("  ", depth), current_type, #children), vim.log.levels.DEBUG)
    end

    -- Check if any direct children contain our target window
    for i, child in ipairs(children) do
      if contains_window(child, target_win) then
        if debug then
          vim.notify(string.format("  %sFound target in child %d", string.rep("  ", depth), i), vim.log.levels.DEBUG)
        end

        -- Target is in this child's subtree
        -- If this container is the type we want, return one representative window from each direct child
        if current_type == container_type then
          -- Return one representative window from each direct child
          -- This ensures we don't try to set different widths on windows in the same col (or heights in same row)
          local representatives = {}
          for _, direct_child in ipairs(children) do
            local rep = get_representative_window(direct_child)
            if rep then
              table.insert(representatives, rep)
            end
          end
          if debug then
            vim.notify(string.format("  %sContainer type matches! Returning %d representative windows", string.rep("  ", depth), #representatives), vim.log.levels.DEBUG)
          end
          return representatives
        end

        if debug then
          vim.notify(string.format("  %sContainer type '%s' != '%s', recursing into child", string.rep("  ", depth), current_type, container_type), vim.log.levels.DEBUG)
        end

        -- Otherwise, recurse into the child to find a deeper container
        local result = traverse(child, depth + 1)
        if result then
          return result
        end

        if debug then
          vim.notify(string.format("  %sNo matching container found in subtree", string.rep("  ", depth)), vim.log.levels.DEBUG)
        end

        -- If we didn't find the right container type in the child,
        -- and this node is NOT the right type, return nil
        -- (the caller will check if THEY are the right container type)
        return nil
      end
    end

    return nil
  end

  return traverse(layout, 0)
end

-- Helper function to find which sibling represents the current window
-- Returns the sibling window ID that shares the same container as current_win
-- position_index: 1 to check row (for horizontal containers), 2 to check column (for vertical containers)
local function find_active_sibling(siblings, current_win, position_index)
  -- Check if current window is directly in the siblings list
  if vim.tbl_contains(siblings, current_win) then
    return current_win
  end

  -- Current window is not the representative - find which sibling shares position with it
  local current_pos = vim.api.nvim_win_get_position(current_win)
  for _, winnr in ipairs(siblings) do
    local sibling_pos = vim.api.nvim_win_get_position(winnr)
    if sibling_pos[position_index] == current_pos[position_index] then
      return winnr
    end
  end

  return nil
end

-- Core resizing logic for a single dimension (width or height)
-- Handles filtering, calculating sizes, and distributing space among windows
local function resize_dimension(params)
  local siblings = params.siblings
  local current_win = params.current_win
  local min_size = params.min_size
  local dimension = params.dimension  -- "width" or "height"
  local position_index = params.position_index  -- 1 for row, 2 for col
  local debug = params.debug

  if not siblings or #siblings <= 1 then
    return
  end

  -- Select dimension-specific API functions
  local get_size, set_size, win_min_option
  if dimension == "width" then
    get_size = vim.api.nvim_win_get_width
    set_size = vim.api.nvim_win_set_width
    win_min_option = vim.o.winminwidth
  else  -- height
    get_size = vim.api.nvim_win_get_height
    set_size = vim.api.nvim_win_set_height
    win_min_option = vim.o.winminheight
  end

  -- Filter out excluded windows
  local valid_siblings = {}
  for _, winnr in ipairs(siblings) do
    if vim.api.nvim_win_is_valid(winnr) and not config.should_exclude_window(winnr) then
      table.insert(valid_siblings, winnr)
    end
  end

  if #valid_siblings <= 1 then
    return
  end

  -- Calculate total available size
  local total_size = 0
  for _, winnr in ipairs(valid_siblings) do
    total_size = total_size + get_size(winnr)
  end

  -- Convert percentage to absolute if needed
  local actual_min_size = min_size
  if min_size > 0 and min_size <= 1 then
    actual_min_size = math.floor(total_size * min_size)
  end

  local current_size = get_size(current_win)
  local active_size = math.max(actual_min_size, current_size)

  -- Find which sibling represents the current window
  local active_sibling = find_active_sibling(valid_siblings, current_win, position_index)

  if debug then
    vim.notify(string.format("Aperture: Setting active window %s to %d (min: %d, actual_min: %d, current: %d, active_sibling: %s)",
      dimension, active_size, min_size, actual_min_size, current_size, active_sibling or "nil"), vim.log.levels.DEBUG)
  end

  pcall(set_size, current_win, active_size)

  -- Distribute remaining size to inactive windows
  local num_inactive = #valid_siblings - 1
  if num_inactive > 0 and active_sibling then
    local remaining_size = total_size - active_size
    local inactive_size = math.floor(remaining_size / num_inactive)
    inactive_size = math.max(inactive_size, win_min_option)

    if debug then
      vim.notify(string.format("Aperture: Setting %d inactive windows to %s %d (skipping %d)",
        num_inactive, dimension, inactive_size, active_sibling), vim.log.levels.DEBUG)
    end

    for _, winnr in ipairs(valid_siblings) do
      if winnr ~= active_sibling then
        pcall(set_size, winnr, inactive_size)
      end
    end
  end
end

-- Automatically resize windows based on focus
function M.autosize_windows(current_win)
  if not config.options.autosize.enabled then
    return
  end

  if config.options.debug then
    vim.notify("Aperture: autosize_windows() called", vim.log.levels.DEBUG)
  end

  local min_width = config.options.autosize.min_width or 80
  local min_height = config.options.autosize.min_height or 20

  -- Get the window layout tree
  local layout = vim.fn.winlayout()

  if config.options.debug then
    vim.notify(string.format("Aperture: Layout tree: %s", vim.inspect(layout)), vim.log.levels.DEBUG)
  end

  if config.options.debug then
    vim.notify(string.format("Aperture: Current window: %d", current_win), vim.log.levels.DEBUG)
  end

  -- Find windows that share a horizontal container (row) with the active window
  if config.options.debug then
    vim.notify("Aperture: Searching for row siblings...", vim.log.levels.DEBUG)
  end
  local row_siblings = find_window_container(layout, current_win, "row", config.options.debug)

  -- Find windows that share a vertical container (col) with the active window
  if config.options.debug then
    vim.notify("Aperture: Searching for col siblings...", vim.log.levels.DEBUG)
  end
  local col_siblings = find_window_container(layout, current_win, "col", config.options.debug)

  if config.options.debug then
    local row_count = row_siblings and #row_siblings or 0
    local col_count = col_siblings and #col_siblings or 0
    vim.notify(string.format("Aperture: Row siblings (%d): %s", row_count, vim.inspect(row_siblings)), vim.log.levels.DEBUG)
    vim.notify(string.format("Aperture: Col siblings (%d): %s", col_count, vim.inspect(col_siblings)), vim.log.levels.DEBUG)

    if not row_siblings then
      vim.notify("Aperture: WARNING - No row siblings found, width won't be adjusted", vim.log.levels.WARN)
    end
    if not col_siblings then
      vim.notify("Aperture: WARNING - No col siblings found, height won't be adjusted", vim.log.levels.WARN)
    end
  end

  -- Resize width for windows in the same row container
  resize_dimension({
    siblings = row_siblings,
    current_win = current_win,
    min_size = min_width,
    dimension = "width",
    position_index = 2,  -- Check column position (windows in same col share width)
    debug = config.options.debug,
  })

  -- Resize height for windows in the same column container
  resize_dimension({
    siblings = col_siblings,
    current_win = current_win,
    min_size = min_height,
    dimension = "height",
    position_index = 1,  -- Check row position (windows in same row share height)
    debug = config.options.debug,
  })
end

-- Update all windows based on focus
function M.update_windows()
  -- Check if either dimming or autosize is enabled
  if not M.enabled and not config.options.autosize.enabled then
    return
  end

  if config.options.debug then
    vim.notify("Aperture: update_windows() called", vim.log.levels.DEBUG)
  end

  local current_win = vim.api.nvim_get_current_win()
  M.current_focus_win = current_win

  -- Apply autosize first (if enabled)
  M.autosize_windows(current_win)

  -- Then apply dimming to all windows (only if dimming is enabled)
  if M.enabled then
    for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if winnr ~= current_win then
        M.dim_window(winnr)
      else
        M.undim_window(winnr)
      end
    end
  end
end

-- Refresh highlights and reapply dimming
function M.refresh()
  do_refresh()
end

-- Set up autocmds for window management (shared by dimming and autosize)
local function setup_autocmds()
  if M.autocmd_group then
    return  -- Already set up
  end

  -- Create autocommand group
  M.autocmd_group = vim.api.nvim_create_augroup("ApertureDimming", { clear = true })

  -- Set up autocmds for window focus changes
  vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
    group = M.autocmd_group,
    callback = function()
      M.update_windows()
    end,
    desc = "Update window dimming and autosize on focus change",
  })

  -- Refresh highlights when colorscheme changes (for dimming)
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = M.autocmd_group,
    callback = function()
      if M.enabled then
        M.refresh()
      end
    end,
    desc = "Refresh dimming on colorscheme change",
  })

  -- Catch dynamically loaded highlights (for dimming)
  vim.api.nvim_create_autocmd({ "LspAttach", "FileType", "Syntax" }, {
    group = M.autocmd_group,
    callback = function()
      debounced_refresh()
    end,
    desc = "Refresh highlights when new ones might be loaded",
  })

  -- Catch buffer-specific highlights (treesitter, etc.) (for dimming)
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = M.autocmd_group,
    callback = function()
      debounced_refresh()
    end,
    desc = "Refresh highlights after buffer load",
  })
end

-- Initialize autosize (set up autocmds if enabled)
function M.init_autosize()
  if config.options.autosize.enabled then
    setup_autocmds()
    M.update_windows()
  end
end

-- Enable the dimming effect
function M.enable()
  if M.enabled then
    return
  end

  M.enabled = true
  M.create_dimmed_highlights()

  -- Set up autocmds if not already set up
  setup_autocmds()

  -- Initial update
  M.update_windows()

  if not config.options.quiet then
    vim.notify("Aperture: Dimming enabled", vim.log.levels.INFO)
  end
end

-- Disable the dimming effect
function M.disable()
  if not M.enabled then
    return
  end

  M.enabled = false

  -- Stop any pending refresh and release the libuv timer handle
  if M.refresh_timer and not M.refresh_timer:is_closing() then
    M.refresh_timer:stop()
    M.refresh_timer:close()
  end
  M.refresh_timer = nil
  M.refresh_pending = false

  -- Remove all dimming from windows
  for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    M.undim_window(winnr)
  end

  -- Clear autocommands only if autosize doesn't still need them.
  -- The augroup is shared between dimming and autosize, so tearing it down
  -- while autosize is enabled would silently break resizing.
  if M.autocmd_group and not config.options.autosize.enabled then
    vim.api.nvim_del_augroup_by_id(M.autocmd_group)
    M.autocmd_group = nil
  end

  if not config.options.quiet then
    vim.notify("Aperture: Dimming disabled", vim.log.levels.INFO)
  end
end

-- Toggle the dimming effect
function M.toggle()
  if M.enabled then
    M.disable()
  else
    M.enable()
  end
end

return M
