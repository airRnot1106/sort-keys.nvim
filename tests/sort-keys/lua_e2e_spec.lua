-- Smoke-checks the custom Lua extractor (dynamic kind, positional pins) through
-- the wired pipeline. Skipped without the lua treesitter parser.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "lua"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("lua end-to-end", function()
  local has_lua

  before_each(function()
    has_lua = ts.has_parser("lua")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts a keyed table by key (kind voted object)", function()
    if not has_lua then
      return pending("lua treesitter parser not available")
    end
    local bufnr = setup_buf({
      "local t = {",
      "  b = 1,",
      "  a = 2,",
      "}",
    })
    set_cursor(1, 2)
    vim.cmd("SortKeys")
    assert.are.same({
      "local t = {",
      "  a = 2,",
      "  b = 1,",
      "}",
    }, lines_of(bufnr))
  end)

  it("sorts an array-like table by element (kind voted array)", function()
    if not has_lua then
      return pending("lua treesitter parser not available")
    end
    local bufnr = setup_buf({ "local t = { 3, 1, 2 }" })
    set_cursor(0, 13)
    vim.cmd("SortKeys")
    assert.are.same({ "local t = { 1, 2, 3 }" }, lines_of(bufnr))
  end)

  it("pins positional fields inside a mixed table and sorts the keyed ones around them", function()
    if not has_lua then
      return pending("lua treesitter parser not available")
    end
    local bufnr = setup_buf({ "local t = { 10, b = 1, a = 2 }" })
    set_cursor(0, 13)
    vim.cmd("SortKeys")
    assert.are.same({ "local t = { 10, a = 2, b = 1 }" }, lines_of(bufnr))
  end)

  it(":DeepSortKeys recurses into nested tables", function()
    if not has_lua then
      return pending("lua treesitter parser not available")
    end
    local bufnr = setup_buf({
      "local t = {",
      "  b = { y = 1, x = 2 },",
      "  a = 3,",
      "}",
    })
    set_cursor(1, 2)
    vim.cmd("DeepSortKeys")
    assert.are.same({
      "local t = {",
      "  a = 3,",
      "  b = { x = 2, y = 1 },",
      "}",
    }, lines_of(bufnr))
  end)

  it("carries an own-line comment with the field it documents", function()
    if not has_lua then
      return pending("lua treesitter parser not available")
    end
    local bufnr = setup_buf({
      "local t = {",
      "  -- bee",
      "  b = 1,",
      "  a = 2,",
      "}",
    })
    set_cursor(1, 2)
    vim.cmd("SortKeys")
    assert.are.same({
      "local t = {",
      "  a = 2,",
      "  -- bee",
      "  b = 1,",
      "}",
    }, lines_of(bufnr))
  end)
end)
