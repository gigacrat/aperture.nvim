local config = require("aperture.config")

describe("config.setup", function()
  local notify

  before_each(function()
    -- Silence the error notification emitted on invalid config.
    notify = vim.notify
    vim.notify = function() end
  end)

  after_each(function()
    vim.notify = notify
  end)

  it("accepts an empty config and populates defaults", function()
    assert.is_true(config.setup())
    assert.equals(0.3, config.options.dim_amount)
    assert.is_false(config.options.autosize.enabled)
  end)

  it("merges user options over defaults", function()
    assert.is_true(config.setup({ dim_amount = 0.5 }))
    assert.equals(0.5, config.options.dim_amount)
    -- untouched keys keep their defaults
    assert.equals(0.0, config.options.greyscale_factor)
  end)

  it("accepts valid autosize and hex background", function()
    assert.is_true(config.setup({
      dim_background = "#1a1a1a",
      autosize = { enabled = true, min_width = 0.5, min_height = 30 },
    }))
  end)

  it("rejects out-of-range dim_amount", function()
    assert.is_false(config.setup({ dim_amount = 2 }))
  end)

  it("rejects a non-number dim_amount", function()
    assert.is_false(config.setup({ dim_amount = "lots" }))
  end)

  it("rejects a malformed hex background", function()
    assert.is_false(config.setup({ dim_background = "1a1a1a" }))
    assert.is_false(config.setup({ dim_background = "#xyz" }))
  end)

  it("rejects a non-boolean enabled", function()
    assert.is_false(config.setup({ enabled = "yes" }))
  end)

  it("rejects a non-table excluded_filetypes", function()
    assert.is_false(config.setup({ excluded_filetypes = "NvimTree" }))
  end)

  it("rejects autosize.min_width <= 0", function()
    assert.is_false(config.setup({ autosize = { min_width = 0 } }))
  end)
end)

describe("config.should_exclude_window", function()
  before_each(function()
    config.setup({ excluded_filetypes = { "help" }, excluded_buftypes = { "prompt" } })
  end)

  it("excludes an excluded filetype", function()
    vim.cmd("enew")
    vim.bo.filetype = "help"
    assert.is_true(config.should_exclude_window(vim.api.nvim_get_current_win()))
  end)

  it("does not exclude an ordinary window", function()
    vim.cmd("enew")
    vim.bo.filetype = "lua"
    vim.bo.buftype = ""
    assert.is_false(config.should_exclude_window(vim.api.nvim_get_current_win()))
  end)

  it("excludes floating windows", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor", row = 1, col = 1, width = 10, height = 5,
    })
    assert.is_true(config.should_exclude_window(win))
    vim.api.nvim_win_close(win, true)
  end)
end)
