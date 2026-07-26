# aperture.nvim

A Neovim plugin that automatically dims unfocused windows and intelligently resizes them to help you maintain visual focus on your current work.

Like a camera's aperture controls both depth of field (what's in focus) and light exposure (how much view you get), this plugin combines visual dimming with smart window sizing.

## Features

- **Automatic window dimming**: Unfocused windows are visually dimmed
- **Automatic window resizing**: Active window dynamically resizes to ensure adequate viewing space (especially useful on laptops)
- **Comprehensive coverage**: Automatically dims ALL highlight groups (syntax, UI, plugins, LSP, treesitter, etc.)
- **Floating window exclusion**: Automatically excludes floating windows (Telescope, LSP hover, etc.)
- **Configurable effects**: Adjust dim amount, greyscale, and sepia toning
- **Smart window distribution**: Inactive windows are evenly resized for visual appeal
- **Smart exclusions**: Exclude specific filetypes, buffer types, and highlight patterns
- **Colorscheme aware**: Automatically refreshes when you change colorschemes
- **Zero configuration**: Works out of the box with sensible defaults

## Requirements

- Neovim >= 0.9 (uses the `nvim_get_hl` API)
- A terminal with true color support and `termguicolors` enabled

## Installation

### Using [Lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "gigacrat/aperture.nvim",
  config = function()
    require('aperture').setup()
  end,
}
```

## Configuration

Default configuration:

```lua
require('aperture').setup({
  enabled = true,                    -- Enable dimming on startup
  dim_amount = 0.3,                  -- Amount to dim unfocused windows (0.0-1.0)
  greyscale_factor = 0.0,            -- Amount of greyscale effect (0.0-1.0)
  sepia_factor = 0.0,                -- Amount of sepia effect (0.0-1.0)
  dim_background = nil,              -- Optional: Override background color (e.g., "#1a1a1a")
  debug = false,                     -- Enable debug logging
  quiet = false,                     -- Suppress enable/disable notifications

  -- Window autosize configuration
  autosize = {
    enabled = false,                 -- Enable automatic window resizing
    min_width = 80,                  -- Minimum width for active window (use 0-1 for percentage, >=1 for absolute columns)
    min_height = 20,                 -- Minimum height for active window (use 0-1 for percentage, >=1 for absolute rows)
  },

  -- Excluded filetypes (won't be dimmed). Empty by default; uncomment as needed.
  excluded_filetypes = {
    -- "NvimTree",
    -- "neo-tree",
    -- "TelescopePrompt",
    -- "lazy",
    -- "mason",
  },

  -- Excluded buffer types (won't be dimmed)
  excluded_buftypes = {
    "prompt",
    -- Add "terminal" here to exclude terminal windows from dimming
  },

  -- Excluded highlight group patterns (Lua patterns)
  excluded_highlight_patterns = {
    "^WinSeparator",   -- Window separators
    -- "^Telescope",   -- Telescope UI (already excluded via floating windows)
    -- "Border$",      -- All borders
  },
})
```

### Configuration Options

#### Dimming Options
- **`enabled`**: Start with dimming enabled (default: `true`)
- **`dim_amount`**: How much to reduce brightness (0.0 = no dimming, 1.0 = maximum dimming)
- **`greyscale_factor`**: How much to desaturate colors (0.0 = full color, 1.0 = full greyscale)
- **`sepia_factor`**: How much sepia tone to apply (0.0 = none, 1.0 = full sepia)
- **`dim_background`**: Optional background color override for dimmed windows (e.g., `"#1a1a1a"`, `"#0d0d0d"`) - useful for transparent colorschemes
- **`debug`**: Enable debug logging to see when highlights are refreshed (default: `false`)
- **`quiet`**: Suppress enable/disable notifications (default: `false`)

#### Autosize Options
- **`autosize.enabled`**: Enable automatic window resizing (default: `false`)
- **`autosize.min_width`**: Minimum width for the active window (default: `80`)
  - Use `0-1` for percentage of available space (e.g., `0.5` = 50% of width)
  - Use `>=1` for absolute columns (e.g., `80` = 80 columns)
- **`autosize.min_height`**: Minimum height for the active window (default: `20`)
  - Use `0-1` for percentage of available space (e.g., `0.6` = 60% of height)
  - Use `>=1` for absolute rows (e.g., `20` = 20 rows)

When autosize is enabled, the active window will be resized to at least the minimum width/height, and remaining space is distributed evenly among inactive windows in the same row/column.

#### Exclusion Options
- **`excluded_filetypes`**: List of filetypes to never dim
- **`excluded_buftypes`**: List of buffer types to never dim (add `"terminal"` to exclude terminal windows)
- **`excluded_highlight_patterns`**: List of Lua patterns for highlight groups to exclude from dimming

### Example Configurations

#### Subtle dimming (recommended for most users)
```lua
require('aperture').setup({
  dim_amount = 0.2,
})
```

#### Strong focus mode with greyscale
```lua
require('aperture').setup({
  dim_amount = 0.4,
  greyscale_factor = 0.3,
})
```

#### Vintage sepia effect
```lua
require('aperture').setup({
  dim_amount = 0.3,
  sepia_factor = 0.5,
})
```

#### Custom background for dimmed windows
```lua
require('aperture').setup({
  dim_amount = 0.3,
  dim_background = "#1a1a1a",  -- Dark grey background for unfocused windows
})
```

#### Laptop/small screen mode (dimming + autosize)
```lua
require('aperture').setup({
  dim_amount = 0.3,
  autosize = {
    enabled = true,
    min_width = 85,   -- Ensure active window is wide enough to code
    min_height = 25,  -- Ensure active window is tall enough to see code
  },
})
```

#### Autosize with percentage-based sizing
```lua
require('aperture').setup({
  dim_amount = 0.3,
  autosize = {
    enabled = true,
    min_width = 0.6,   -- Active window gets 60% of available width
    min_height = 0.7,  -- Active window gets 70% of available height
  },
})
```

#### Autosize only (no dimming)
```lua
require('aperture').setup({
  dim_amount = 0.0,  -- No dimming
  autosize = {
    enabled = true,
    min_width = 100,
    min_height = 30,
  },
})
```

#### Start disabled, toggle manually
```lua
require('aperture').setup({
  enabled = false,
})
```

## Usage

The plugin works automatically once installed. Whenever you switch windows, unfocused windows will be dimmed.

### Commands

- `:ApertureEnable` - Enable window dimming
- `:ApertureDisable` - Disable window dimming
- `:ApertureToggle` - Toggle dimming on/off
- `:ApertureRefresh` - Refresh dimming (useful after colorscheme changes)
- `:ApertureStats` - Show diagnostic statistics about captured highlights
- `:ApertureReload` - Reload the plugin (development)

### Lua API

```lua
-- Enable dimming
require('aperture').enable()

-- Disable dimming
require('aperture').disable()

-- Toggle dimming
require('aperture').toggle()

-- Refresh dimming (e.g., after changing config)
require('aperture').refresh()

-- Check if enabled
if require('aperture').is_enabled() then
  print("Dimming is active")
end

-- Get diagnostic statistics about captured highlight groups
local stats = require('aperture').get_stats()
-- => { total, with_fg, with_bg, with_sp, with_attrs_only }
```

### Keybindings

You can set up custom keybindings in your config:

```lua
vim.keymap.set('n', '<leader>at', '<cmd>ApertureToggle<cr>', { desc = 'Toggle window dimming' })
```

## How It Works

1. The plugin dynamically scans **all** currently defined highlight groups (syntax, UI, plugins, LSP, etc.)
2. Creates dimmed/transformed versions of each highlight group based on your configuration
3. When you switch windows, applies these dimmed highlights to unfocused windows using `winhighlight`
4. The focused window always uses the original, undimmed highlights
5. Automatically refreshes and rescans when you change colorschemes

This comprehensive approach means it works with any colorscheme, any plugin, and any custom highlights without requiring manual configuration.

## Development

### Hot Reloading

Use the built-in reload command:

```vim
:ApertureReload
```

Or manually reload modules:

```lua
:lua package.loaded['aperture'] = nil
:lua package.loaded['aperture.config'] = nil
:lua package.loaded['aperture.core'] = nil
:lua package.loaded['aperture.highlight'] = nil
:lua require('aperture').setup()
```

### Testing Locally

1. Make changes to your plugin code
2. Run `:ApertureReload` to reload without restarting Neovim
3. Test by switching between windows or running `:ApertureRefresh`

For full reload including `plugin/` files:

```vim
:Lazy reload aperture
```

## Project Structure

```
aperture.nvim/
├── lua/
│   └── aperture/
│       ├── init.lua       # Main entry point with setup()
│       ├── config.lua     # Configuration and defaults
│       ├── core.lua       # Window focus tracking and dimming logic
│       └── highlight.lua  # Color manipulation functions
├── plugin/
│   └── aperture.lua       # User commands
├── doc/
│   └── aperture.txt       # Help documentation (:help aperture)
└── README.md
```

## Troubleshooting

### Dimming not working
- Check if dimming is enabled: `:lua =require('aperture').is_enabled()`
- Try refreshing: `:ApertureRefresh`
- Ensure your terminal supports true color

### Colors look wrong
- Adjust `dim_amount` to a lower value (e.g., 0.2)
- Try reducing or disabling `greyscale_factor` and `sepia_factor`
- Some colorschemes may not work well with all effects

### Terminal windows

**Important limitation**: Terminal windows have partial dimming support due to how Neovim's terminal emulator works.

#### What Gets Dimmed
- **Default text** (using Normal/Terminal highlight groups) ✓ Dims correctly
- **UI elements** (line numbers, borders, statusline) ✓ Dims correctly

#### What Doesn't Get Dimmed
- **ANSI colored text** (program output like `ls --color`, `git status`) ✗ Stays bright

#### Technical Explanation

Neovim's terminal emulator has two rendering layers:

1. **ANSI color palette** (`g:terminal_color_0` through `g:terminal_color_15`) - Controls the 16 terminal colors
2. **Editor highlights** - Overlays on top with higher precedence

The plugin can dynamically dim editor highlights by switching window highlight namespaces. However, **the ANSI color palette is only read once at `TermOpen` and cannot be changed dynamically**. This is a fundamental limitation of Neovim's terminal implementation (see [neovim/neovim#8301](https://github.com/neovim/neovim/issues/8301)).

This means:
- When you focus/unfocus a terminal window, the ANSI colors stay the same
- Colored terminal output (prompts, syntax highlighting, git diffs) remains at full brightness
- Only the default text and UI elements will dim

#### Excluding Terminals

Since terminals cannot be fully dimmed, you may want to exclude them entirely:

```lua
require('aperture').setup({
  excluded_buftypes = { "prompt", "terminal" },
})
```

This will keep terminal windows at full brightness while still dimming regular editor windows.

### Specific windows should be excluded

Add the filetype or buftype to your config:

```lua
require('aperture').setup({
  excluded_filetypes = { "your_filetype" },
  excluded_buftypes = { "your_buftype" },
})
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details
