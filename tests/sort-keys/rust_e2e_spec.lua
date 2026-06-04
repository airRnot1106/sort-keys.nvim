local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "rust"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("rust end-to-end", function()
  local has_rust

  before_each(function()
    has_rust = ts.has_parser("rust")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts struct-literal fields", function()
    if not has_rust then
      return pending("rust treesitter parser not available")
    end
    local bufnr = setup_buf({ "let x = S { b: 1, a: 2 };" })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ "let x = S { a: 2, b: 1 };" }, lines_of(bufnr))
  end)

  it("fences ..base so fields don't reorder across it", function()
    if not has_rust then
      return pending("rust treesitter parser not available")
    end
    local bufnr = setup_buf({ "let x = S { c: 1, b: 2, ..base };" })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ "let x = S { b: 2, c: 1, ..base };" }, lines_of(bufnr))
  end)

  it("sorts struct-definition fields, carrying #[attr] with its field", function()
    if not has_rust then
      return pending("rust treesitter parser not available")
    end
    local bufnr = setup_buf({ "struct S {", "  #[serde]", "  b: i32,", "  a: i32,", "}" })
    set_cursor(2, 2)
    vim.cmd("SortKeys")
    assert.are.same({ "struct S {", "  a: i32,", "  #[serde]", "  b: i32,", "}" }, lines_of(bufnr))
  end)

  it("sorts a use list", function()
    if not has_rust then
      return pending("rust treesitter parser not available")
    end
    local bufnr = setup_buf({ "use a::{c, b, d};" })
    set_cursor(0, 8)
    vim.cmd("SortKeys")
    assert.are.same({ "use a::{b, c, d};" }, lines_of(bufnr))
  end)
end)
