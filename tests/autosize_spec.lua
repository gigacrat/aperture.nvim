local core = require("aperture.core")
local config = require("aperture.config")

local internal = core._internal

-- Layout-tree unit tests. These exercise the pure traversal helpers against
-- hand-built winlayout() trees, so they don't depend on the real UI geometry.
-- winlayout() node shapes: {"leaf", winid}, {"row", {children}}, {"col", {children}}.
describe("collect_leaf_windows", function()
  it("returns the single id for a lone leaf", function()
    assert.same({ 1000 }, internal.collect_leaf_windows({ "leaf", 1000 }))
  end)

  it("collects leaves left-to-right from a row", function()
    local layout = { "row", { { "leaf", 1 }, { "leaf", 2 }, { "leaf", 3 } } }
    assert.same({ 1, 2, 3 }, internal.collect_leaf_windows(layout))
  end)

  it("collects leaves from a nested col/row tree in traversal order", function()
    local layout = {
      "col",
      {
        { "leaf", 1 },
        { "row", { { "leaf", 2 }, { "leaf", 3 } } },
      },
    }
    assert.same({ 1, 2, 3 }, internal.collect_leaf_windows(layout))
  end)
end)

describe("get_representative_window", function()
  it("returns the id of a leaf node", function()
    assert.equals(42, internal.get_representative_window({ "leaf", 42 }))
  end)

  it("returns the first leaf of a container", function()
    local node = { "row", { { "leaf", 7 }, { "leaf", 8 } } }
    assert.equals(7, internal.get_representative_window(node))
  end)

  it("returns nil for an empty container", function()
    assert.is_nil(internal.get_representative_window({ "row", {} }))
  end)
end)

describe("find_window_container", function()
  it("returns one representative per child of a matching row container", function()
    local layout = { "row", { { "leaf", 1 }, { "leaf", 2 } } }
    assert.same({ 1, 2 }, internal.find_window_container(layout, 1, "row"))
  end)

  it("returns nil when no container of the requested type holds the window", function()
    -- A flat row has no enclosing "col" for its windows.
    local layout = { "row", { { "leaf", 1 }, { "leaf", 2 } } }
    assert.is_nil(internal.find_window_container(layout, 1, "col"))
  end)

  it("recurses into a nested row to find the inner container", function()
    local layout = {
      "col",
      {
        { "leaf", 1 },
        { "row", { { "leaf", 2 }, { "leaf", 3 } } },
      },
    }
    -- Window 2 shares a row with window 3.
    assert.same({ 2, 3 }, internal.find_window_container(layout, 2, "row"))
  end)

  it("returns column representatives using the first leaf of each child", function()
    local layout = {
      "col",
      {
        { "leaf", 1 },
        { "row", { { "leaf", 2 }, { "leaf", 3 } } },
      },
    }
    -- The outer col has two children: leaf 1, and a row (rep = first leaf, 2).
    assert.same({ 1, 2 }, internal.find_window_container(layout, 2, "col"))
  end)

  it("returns nil for a window that has no matching container", function()
    local layout = {
      "col",
      {
        { "leaf", 1 },
        { "row", { { "leaf", 2 }, { "leaf", 3 } } },
      },
    }
    -- Window 1 is alone in its column slot; it shares no row with anyone.
    assert.is_nil(internal.find_window_container(layout, 1, "row"))
  end)
end)

-- Integration tests: build real splits and confirm autosize_windows grows the
-- active window and shrinks its siblings. A generous editor size keeps the
-- arithmetic well clear of winminwidth/winminheight so results are stable.
describe("autosize_windows", function()
  local saved_columns, saved_lines

  before_each(function()
    saved_columns, saved_lines = vim.o.columns, vim.o.lines
    vim.o.columns = 300
    vim.o.lines = 90
    -- Collapse back to a single window before each case.
    vim.cmd("only")
  end)

  after_each(function()
    vim.cmd("only")
    vim.o.columns = saved_columns
    vim.o.lines = saved_lines
  end)

  it("widens the active window across a row of vsplits", function()
    config.setup({ autosize = { enabled = true, min_width = 120, min_height = 20 } })

    vim.cmd("vsplit")
    vim.cmd("vsplit")
    local wins = vim.api.nvim_tabpage_list_wins(0)
    assert.equals(3, #wins)

    local active = wins[1]
    vim.api.nvim_set_current_win(active)
    core.autosize_windows(active)

    local active_width = vim.api.nvim_win_get_width(active)
    assert.equals(120, active_width)
    for _, w in ipairs(wins) do
      if w ~= active then
        assert.is_true(vim.api.nvim_win_get_width(w) < active_width)
      end
    end
  end)

  it("heightens the active window across a column of splits", function()
    config.setup({ autosize = { enabled = true, min_width = 80, min_height = 40 } })

    vim.cmd("split")
    vim.cmd("split")
    local wins = vim.api.nvim_tabpage_list_wins(0)
    assert.equals(3, #wins)

    local active = wins[1]
    vim.api.nvim_set_current_win(active)
    core.autosize_windows(active)

    local active_height = vim.api.nvim_win_get_height(active)
    assert.equals(40, active_height)
    for _, w in ipairs(wins) do
      if w ~= active then
        assert.is_true(vim.api.nvim_win_get_height(w) < active_height)
      end
    end
  end)

  it("does nothing when autosize is disabled", function()
    config.setup({ autosize = { enabled = false } })

    vim.cmd("vsplit")
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local before = vim.api.nvim_win_get_width(wins[1])

    vim.api.nvim_set_current_win(wins[1])
    core.autosize_windows(wins[1])

    assert.equals(before, vim.api.nvim_win_get_width(wins[1]))
  end)

  it("leaves a lone window untouched", function()
    config.setup({ autosize = { enabled = true, min_width = 120 } })

    local win = vim.api.nvim_get_current_win()
    local before = vim.api.nvim_win_get_width(win)
    core.autosize_windows(win)

    assert.equals(before, vim.api.nvim_win_get_width(win))
  end)
end)
