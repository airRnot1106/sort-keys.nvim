local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

describe("sort-keys.core.applier", function()
  local applier

  before_each(function()
    package.loaded["sort-keys.core.applier"] = nil
    applier = require("sort-keys.core.applier")
  end)

  it("rewrites a single-line JSON object to reflect the Outline's new entry order", function()
    -- Buffer:    { "c": 3, "a": 1, "b": 2 }
    -- positions: 0         1         2
    --            0123456789012345678901234
    --            { "c": 3, "a": 1, "b": 2 }
    local bufnr = make_buf({ '{ "c": 3, "a": 1, "b": 2 }' })

    -- Pre-built Outline whose entries are already in target order: a, b, c.
    local outline = {
      kind = "object",
      range = { 0, 0, 0, 26 },
      separator = ", ",
      entries = {
        {
          kind = "pair",
          sort_key = "a",
          range = { 0, 10, 0, 16 }, -- '"a": 1'
          movable = true,
          anchor = 2,
          attached = {},
          child = nil,
        },
        {
          kind = "pair",
          sort_key = "b",
          range = { 0, 18, 0, 24 }, -- '"b": 2'
          movable = true,
          anchor = 3,
          attached = {},
          child = nil,
        },
        {
          kind = "pair",
          sort_key = "c",
          range = { 0, 2, 0, 8 }, -- '"c": 3'
          movable = true,
          anchor = 1,
          attached = {},
          child = nil,
        },
      },
    }

    applier.apply(bufnr, outline)

    local lines = get_lines(bufnr)
    assert.equals(1, #lines)
    assert.equals('{ "a": 1, "b": 2, "c": 3 }', lines[1])
  end)

  it("rewrites a JSON array to reflect the Outline's new element order", function()
    -- Buffer: [ "c", "a", "b" ]
    --         0123456789012345
    local bufnr = make_buf({ '[ "c", "a", "b" ]' })

    local outline = {
      kind = "array",
      range = { 0, 0, 0, 17 },
      separator = ", ",
      entries = {
        {
          kind = "element",
          sort_key = "a",
          range = { 0, 7, 0, 10 },
          movable = true,
          anchor = 2,
          attached = {},
        },
        {
          kind = "element",
          sort_key = "b",
          range = { 0, 12, 0, 15 },
          movable = true,
          anchor = 3,
          attached = {},
        },
        {
          kind = "element",
          sort_key = "c",
          range = { 0, 2, 0, 5 },
          movable = true,
          anchor = 1,
          attached = {},
        },
      },
    }

    applier.apply(bufnr, outline)
    assert.equals('[ "a", "b", "c" ]', get_lines(bufnr)[1])
  end)
end)
