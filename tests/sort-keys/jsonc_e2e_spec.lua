-- Smoke-checks the comment-aware pipeline on JSONC (json parser + comments).
-- The point of these cases is that a comment travels with the pair it
-- documents across a reorder, not that it stays at a fixed line.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "jsonc"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("jsonc end-to-end", function()
  local has_json

  before_each(function()
    has_json = ts.has_parser("json")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("carries an own-line leading comment with its pair", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      "  // banana",
      '  "banana": 1,',
      '  "apple": 2',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({
      "{",
      '  "apple": 2,',
      "  // banana",
      '  "banana": 1',
      "}",
    }, lines_of(bufnr))
  end)

  it("carries a same-line trailing comment with its pair", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      '  "banana": 1, // yellow',
      '  "apple": 2',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({
      "{",
      '  "apple": 2,',
      '  "banana": 1 // yellow',
      "}",
    }, lines_of(bufnr))
  end)

  it(":DeepSortKeys recurses and keeps each comment with its pair", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      '  "b": {',
      "    // why y",
      '    "y": 1,',
      '    "x": 2',
      "  },",
      '  "a": 1',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("DeepSortKeys")
    assert.are.same({
      "{",
      '  "a": 1,',
      '  "b": {',
      '    "x": 2,',
      "    // why y",
      '    "y": 1',
      "  }",
      "}",
    }, lines_of(bufnr))
  end)

  it("preserves a trailing comma when the last entry also has a trailing comment", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      '  "a": 1,',
      '  "b": 2, // last',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({
      "{",
      '  "a": 1,',
      '  "b": 2, // last',
      "}",
    }, lines_of(bufnr))
  end)

  it("sorts comment-free JSONC just like JSON", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({ '{ "b": 2, "a": 1 }' })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ '{ "a": 1, "b": 2 }' }, lines_of(bufnr))
  end)
end)
