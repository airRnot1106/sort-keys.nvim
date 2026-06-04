-- Smoke-checks JavaScript on the generic extractor, exercising the
-- @sortkeys.pin / @sortkeys.fence captures (spread/method) end to end.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "javascript"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("javascript end-to-end", function()
  local has_js

  before_each(function()
    has_js = ts.has_parser("javascript")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts object keys", function()
    if not has_js then
      return pending("javascript treesitter parser not available")
    end
    local bufnr = setup_buf({ "const o = { b: 1, a: 2 };" })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ "const o = { a: 2, b: 1 };" }, lines_of(bufnr))
  end)

  it("sorts shorthand properties", function()
    if not has_js then
      return pending("javascript treesitter parser not available")
    end
    local bufnr = setup_buf({ "const o = { b, a, c };" })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ "const o = { a, b, c };" }, lines_of(bufnr))
  end)

  it("fences a spread so keys never cross it", function()
    if not has_js then
      return pending("javascript treesitter parser not available")
    end
    local bufnr = setup_buf({ "const o = { ...x, b: 1, a: 2 };" })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ "const o = { ...x, a: 2, b: 1 };" }, lines_of(bufnr))
  end)

  it("pins a method in place while keys sort around it", function()
    if not has_js then
      return pending("javascript treesitter parser not available")
    end
    local bufnr = setup_buf({ "const o = { foo() {}, b: 1, a: 2 };" })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ "const o = { foo() {}, a: 2, b: 1 };" }, lines_of(bufnr))
  end)

  it("sorts a string key by its unquoted value", function()
    if not has_js then
      return pending("javascript treesitter parser not available")
    end
    local bufnr = setup_buf({ 'const o = { "b-x": 1, a: 2 };' })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ 'const o = { a: 2, "b-x": 1 };' }, lines_of(bufnr))
  end)

  it("sorts an array of numbers", function()
    if not has_js then
      return pending("javascript treesitter parser not available")
    end
    local bufnr = setup_buf({ "const o = [3, 1, 2];" })
    set_cursor(0, 11)
    vim.cmd("SortKeys")
    assert.are.same({ "const o = [1, 2, 3];" }, lines_of(bufnr))
  end)

  it(":DeepSortKeys recurses into nested objects", function()
    if not has_js then
      return pending("javascript treesitter parser not available")
    end
    local bufnr = setup_buf({
      "const o = {",
      "  b: { y: 1, x: 2 },",
      "  a: 3,",
      "};",
    })
    set_cursor(1, 2)
    vim.cmd("DeepSortKeys")
    assert.are.same({
      "const o = {",
      "  a: 3,",
      "  b: { x: 2, y: 1 },",
      "};",
    }, lines_of(bufnr))
  end)

  it("leaves an array with an elision hole untouched instead of corrupting it", function()
    if not has_js then
      return pending("javascript treesitter parser not available")
    end
    -- A hole has no node, so the gap carries an extra comma; sorting would
    -- duplicate it. The container is left as-is rather than mangled.
    local bufnr = setup_buf({ "const a = [3, , 1];" })
    set_cursor(0, 11)
    vim.cmd("SortKeys")
    assert.are.same({ "const a = [3, , 1];" }, lines_of(bufnr))
  end)
end)
