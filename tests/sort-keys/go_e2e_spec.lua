local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "go"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("go end-to-end", function()
  local has_go

  before_each(function()
    has_go = ts.has_parser("go")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts keyed struct-literal fields", function()
    if not has_go then
      return pending("go treesitter parser not available")
    end
    local bufnr = setup_buf({ "var x = T{B: 1, A: 2}" })
    set_cursor(0, 10)
    vim.cmd("SortKeys")
    assert.are.same({ "var x = T{A: 2, B: 1}" }, lines_of(bufnr))
  end)

  it("sorts struct-definition fields", function()
    if not has_go then
      return pending("go treesitter parser not available")
    end
    local bufnr = setup_buf({ "type T struct {", "  B int", "  A string", "}" })
    set_cursor(1, 2)
    vim.cmd("SortKeys")
    assert.are.same({ "type T struct {", "  A string", "  B int", "}" }, lines_of(bufnr))
  end)

  it("sorts an import block by path", function()
    if not has_go then
      return pending("go treesitter parser not available")
    end
    local bufnr = setup_buf({ "import (", '  "b"', '  "a"', ")" })
    set_cursor(1, 2)
    vim.cmd("SortKeys")
    assert.are.same({ "import (", '  "a"', '  "b"', ")" }, lines_of(bufnr))
  end)

  it("pins an embedded field and sorts the named fields around it", function()
    if not has_go then
      return pending("go treesitter parser not available")
    end
    local bufnr = setup_buf({ "type T struct {", "  io.Reader", "  Z string", "  A int", "}" })
    set_cursor(1, 2)
    vim.cmd("SortKeys")
    assert.are.same(
      { "type T struct {", "  io.Reader", "  A int", "  Z string", "}" },
      lines_of(bufnr)
    )
  end)

  it(":DeepSortKeys recurses into a pointer struct literal &T{...}", function()
    if not has_go then
      return pending("go treesitter parser not available")
    end
    local bufnr = setup_buf({ "var x = Outer{Inner: &T{B: 1, A: 2}, Apple: 3}" })
    set_cursor(0, 14)
    vim.cmd("DeepSortKeys")
    assert.are.same({ "var x = Outer{Apple: 3, Inner: &T{A: 2, B: 1}}" }, lines_of(bufnr))
  end)

  it("leaves a positional/slice literal untouched (order is meaningful)", function()
    if not has_go then
      return pending("go treesitter parser not available")
    end
    local bufnr = setup_buf({ "var x = []int{3, 1, 2}" })
    set_cursor(0, 14)
    vim.cmd("SortKeys")
    assert.are.same({ "var x = []int{3, 1, 2}" }, lines_of(bufnr))
  end)
end)
