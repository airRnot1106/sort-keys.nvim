local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "gleam"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("gleam end-to-end", function()
  local has_gleam

  before_each(function()
    has_gleam = ts.has_parser("gleam")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts labelled record arguments", function()
    if not has_gleam then
      return pending("gleam treesitter parser not available")
    end
    local bufnr = setup_buf({ "pub fn x() { Foo(b: 1, a: 2) }" })
    set_cursor(0, 17)
    vim.cmd("SortKeys")
    assert.are.same({ "pub fn x() { Foo(a: 2, b: 1) }" }, lines_of(bufnr))
  end)

  it("pins a positional argument before the labelled ones", function()
    if not has_gleam then
      return pending("gleam treesitter parser not available")
    end
    local bufnr = setup_buf({ "pub fn x() { Foo(99, b: 1, a: 2) }" })
    set_cursor(0, 17)
    vim.cmd("SortKeys")
    assert.are.same({ "pub fn x() { Foo(99, a: 2, b: 1) }" }, lines_of(bufnr))
  end)

  it("sorts record-definition fields", function()
    if not has_gleam then
      return pending("gleam treesitter parser not available")
    end
    local bufnr = setup_buf({ "pub type Foo {", "  Foo(b: Int, a: String)", "}" })
    set_cursor(1, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "pub type Foo {", "  Foo(a: String, b: Int)", "}" }, lines_of(bufnr))
  end)

  it("sorts a record update, keeping the ..spread", function()
    if not has_gleam then
      return pending("gleam treesitter parser not available")
    end
    local bufnr = setup_buf({ "pub fn x() { Foo(..base, c: 1, a: 2) }" })
    set_cursor(0, 25)
    vim.cmd("SortKeys")
    assert.are.same({ "pub fn x() { Foo(..base, a: 2, c: 1) }" }, lines_of(bufnr))
  end)

  it("sorts a case-clause record pattern's labelled fields", function()
    if not has_gleam then
      return pending("gleam treesitter parser not available")
    end
    local bufnr =
      setup_buf({ "pub fn x(v) {", "  case v {", "    Foo(b: 1, a: 2) -> 0", "  }", "}" })
    set_cursor(2, 9)
    vim.cmd("SortKeys")
    assert.are.same(
      { "pub fn x(v) {", "  case v {", "    Foo(a: 2, b: 1) -> 0", "  }", "}" },
      lines_of(bufnr)
    )
  end)

  it(":DeepSortKeys recurses into a record passed positionally", function()
    if not has_gleam then
      return pending("gleam treesitter parser not available")
    end
    local bufnr = setup_buf({ "pub fn x() { outer(Bar(x: 1, w: 2), z: 3, y: 4) }" })
    set_cursor(0, 19)
    vim.cmd("DeepSortKeys")
    assert.are.same({ "pub fn x() { outer(Bar(w: 2, x: 1), y: 4, z: 3) }" }, lines_of(bufnr))
  end)
end)
