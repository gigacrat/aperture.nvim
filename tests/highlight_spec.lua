local highlight = require("aperture.highlight")

describe("hex_to_rgb", function()
  it("parses a 6-digit hex color", function()
    local r, g, b = highlight.hex_to_rgb("#ff8800")
    assert.equals(255, r)
    assert.equals(136, g)
    assert.equals(0, b)
  end)

  it("parses without a leading #", function()
    local r, g, b = highlight.hex_to_rgb("00ff00")
    assert.same({ 0, 255, 0 }, { r, g, b })
  end)

  it("returns nil for empty, NONE, or nil input", function()
    assert.is_nil(highlight.hex_to_rgb(nil))
    assert.is_nil(highlight.hex_to_rgb(""))
    assert.is_nil(highlight.hex_to_rgb("NONE"))
  end)

  it("returns nil for a wrong-length string", function()
    assert.is_nil(highlight.hex_to_rgb("#fff"))
  end)
end)

describe("rgb_to_hex", function()
  it("formats and zero-pads channels", function()
    assert.equals("#ff8800", highlight.rgb_to_hex(255, 136, 0))
    assert.equals("#000000", highlight.rgb_to_hex(0, 0, 0))
  end)

  it("clamps out-of-range values", function()
    assert.equals("#ff0000", highlight.rgb_to_hex(300, -20, 0))
  end)

  it("rounds to the nearest integer", function()
    assert.equals("#020202", highlight.rgb_to_hex(1.5, 1.5, 1.5))
  end)
end)

describe("apply_dim", function()
  it("scales channels toward black", function()
    assert.same({ 50, 50, 50 }, { highlight.apply_dim(100, 100, 100, 0.5) })
  end)

  it("is a no-op at amount 0", function()
    assert.same({ 100, 200, 50 }, { highlight.apply_dim(100, 200, 50, 0) })
  end)
end)

describe("apply_greyscale", function()
  it("is a no-op at factor 0", function()
    assert.same({ 100, 200, 50 }, { highlight.apply_greyscale(100, 200, 50, 0) })
  end)

  it("collapses channels to a single luminance at factor 1", function()
    local r, g, b = highlight.apply_greyscale(100, 200, 50, 1)
    assert.equals(r, g)
    assert.equals(g, b)
  end)
end)

describe("apply_sepia", function()
  it("is a no-op at factor 0", function()
    assert.same({ 10, 20, 30 }, { highlight.apply_sepia(10, 20, 30, 0) })
  end)
end)

describe("transform_color", function()
  it("dims a color by the given amount", function()
    -- 255 * (1 - 0.5) = 127.5 -> rounds to 128 -> 0x80
    assert.equals("#808080", highlight.transform_color("#ffffff", 0.5, 0, 0))
  end)

  it("returns the color unchanged with no effects", function()
    assert.equals("#abcdef", highlight.transform_color("#abcdef", 0, 0, 0))
  end)

  it("returns nil for an invalid color", function()
    assert.is_nil(highlight.transform_color("NONE", 0.5, 0, 0))
  end)
end)

describe("transform_highlight", function()
  it("dims numeric fg/bg/sp into hex strings", function()
    local hl = { fg = 0xffffff, bg = 0x000000, sp = 0xffffff, bold = true }
    local out = highlight.transform_highlight(hl, 0.5, 0, 0)
    assert.equals("#808080", out.fg)
    assert.equals("#000000", out.bg)
    assert.equals("#808080", out.sp)
    assert.is_true(out.bold) -- non-color attributes are preserved
  end)

  it("returns nil when given nil", function()
    assert.is_nil(highlight.transform_highlight(nil, 0.5, 0, 0))
  end)
end)

describe("get_all_highlights", function()
  it("captures a group whose only attribute is reverse", function()
    vim.api.nvim_set_hl(0, "ApertureTestReverse", { reverse = true })
    local all = highlight.get_all_highlights()
    assert.is_not_nil(all["ApertureTestReverse"])
    assert.is_true(all["ApertureTestReverse"].reverse)
  end)

  it("skips a group with no rendering attributes", function()
    vim.api.nvim_set_hl(0, "ApertureTestEmpty", {})
    local all = highlight.get_all_highlights()
    assert.is_nil(all["ApertureTestEmpty"])
  end)
end)
