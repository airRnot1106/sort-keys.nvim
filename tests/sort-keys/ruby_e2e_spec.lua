local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "ruby"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("ruby end-to-end", function()
  local has_rb

  before_each(function()
    has_rb = ts.has_parser("ruby")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts symbol-key hash pairs", function()
    if not has_rb then
      return pending("ruby treesitter parser not available")
    end
    local bufnr = setup_buf({ "h = { b: 1, a: 2 }" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "h = { a: 2, b: 1 }" }, lines_of(bufnr))
  end)

  it("fences a ** splat so keys never cross it", function()
    if not has_rb then
      return pending("ruby treesitter parser not available")
    end
    local bufnr = setup_buf({ "h = { **base, b: 1, a: 2 }" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "h = { **base, a: 2, b: 1 }" }, lines_of(bufnr))
  end)

  it("sorts an array", function()
    if not has_rb then
      return pending("ruby treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = [3, 1, 2]" })
    set_cursor(0, 5)
    vim.cmd("SortKeys")
    assert.are.same({ "x = [1, 2, 3]" }, lines_of(bufnr))
  end)
end)
