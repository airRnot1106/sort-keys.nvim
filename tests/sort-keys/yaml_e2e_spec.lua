local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "yaml"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("yaml end-to-end", function()
  local has_yaml

  before_each(function()
    has_yaml = ts.has_parser("yaml")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts a top-level block mapping (newline-separated)", function()
    if not has_yaml then
      return pending("yaml treesitter parser not available")
    end
    local bufnr = setup_buf({ "b: 1", "a: 2", "c: 3" })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "a: 2", "b: 1", "c: 3" }, lines_of(bufnr))
  end)

  it("sorts a flow mapping (comma-separated)", function()
    if not has_yaml then
      return pending("yaml treesitter parser not available")
    end
    local bufnr = setup_buf({ "x: {b: 1, a: 2}" })
    set_cursor(0, 4)
    vim.cmd("SortKeys")
    assert.are.same({ "x: {a: 2, b: 1}" }, lines_of(bufnr))
  end)

  it("sorts a block sequence (the `- ` items)", function()
    if not has_yaml then
      return pending("yaml treesitter parser not available")
    end
    local bufnr = setup_buf({ "- b", "- a", "- c" })
    set_cursor(0, 2)
    vim.cmd("SortKeys")
    assert.are.same({ "- a", "- b", "- c" }, lines_of(bufnr))
  end)

  it("sorts a flow sequence", function()
    if not has_yaml then
      return pending("yaml treesitter parser not available")
    end
    local bufnr = setup_buf({ "x: [3, 1, 2]" })
    set_cursor(0, 5)
    vim.cmd("SortKeys")
    assert.are.same({ "x: [1, 2, 3]" }, lines_of(bufnr))
  end)

  it("does not misread an own-line comment as the separator", function()
    if not has_yaml then
      return pending("yaml treesitter parser not available")
    end
    -- The comment documents the key below it (a), so it travels with a; no
    -- stray "#" is spliced as a separator.
    local bufnr = setup_buf({ "b: 1", "# c", "a: 2" })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "# c", "a: 2", "b: 1" }, lines_of(bufnr))
  end)

  it(":DeepSortKeys recurses into a nested block mapping", function()
    if not has_yaml then
      return pending("yaml treesitter parser not available")
    end
    local bufnr = setup_buf({
      "root:",
      "  b: 1",
      "  a: 2",
      "z: 3",
    })
    set_cursor(0, 0)
    vim.cmd("DeepSortKeys")
    assert.are.same({
      "root:",
      "  a: 2",
      "  b: 1",
      "z: 3",
    }, lines_of(bufnr))
  end)
end)
