local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "python"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("python end-to-end", function()
  local has_py

  before_each(function()
    has_py = ts.has_parser("python")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts dict keys", function()
    if not has_py then
      return pending("python treesitter parser not available")
    end
    local bufnr = setup_buf({ "d = { 'b': 1, 'a': 2 }" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "d = { 'a': 2, 'b': 1 }" }, lines_of(bufnr))
  end)

  it("fences a ** splat so keys never cross it", function()
    if not has_py then
      return pending("python treesitter parser not available")
    end
    local bufnr = setup_buf({ "d = { **base, 'b': 1, 'a': 2 }" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "d = { **base, 'a': 2, 'b': 1 }" }, lines_of(bufnr))
  end)

  it("sorts a list and carries comments with :DeepSortKeys", function()
    if not has_py then
      return pending("python treesitter parser not available")
    end
    local bufnr = setup_buf({
      "d = {",
      "  # bee",
      "  'b': [3, 1, 2],",
      "  'a': 3,",
      "}",
    })
    set_cursor(0, 4)
    vim.cmd("DeepSortKeys")
    assert.are.same({
      "d = {",
      "  'a': 3,",
      "  # bee",
      "  'b': [1, 2, 3],",
      "}",
    }, lines_of(bufnr))
  end)
end)
