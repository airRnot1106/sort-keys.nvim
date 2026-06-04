local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "kdl"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("kdl end-to-end", function()
  local has_kdl

  before_each(function()
    has_kdl = ts.has_parser("kdl")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts a node's properties", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    local bufnr = setup_buf({ "node b=1 a=2 c=3" })
    set_cursor(0, 5)
    vim.cmd("SortKeys")
    assert.are.same({ "node a=2 b=1 c=3" }, lines_of(bufnr))
  end)

  it("keeps the children block while sorting properties", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    local bufnr = setup_buf({ "node b=1 a=2 {", "  child", "}" })
    set_cursor(0, 5)
    vim.cmd("SortKeys")
    assert.are.same({ "node a=2 b=1 {", "  child", "}" }, lines_of(bufnr))
  end)

  it("pins a positional argument so it is never dropped", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    local bufnr = setup_buf({ "node a=1 c=3 99 b=2" })
    set_cursor(0, 5)
    vim.cmd("SortKeys")
    assert.are.same({ "node a=1 b=2 99 c=3" }, lines_of(bufnr))
  end)

  it("sorts properties across `\\` line continuations", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    local bufnr = setup_buf({ "node \\", "  b=2 \\", "  a=1" })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "node \\", "  a=1 \\", "  b=2" }, lines_of(bufnr))
  end)
end)
