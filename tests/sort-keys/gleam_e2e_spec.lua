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
end)
