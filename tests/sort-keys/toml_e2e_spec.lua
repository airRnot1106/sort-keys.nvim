local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "toml"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("toml end-to-end", function()
  local has_toml

  before_each(function()
    has_toml = ts.has_parser("toml")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts an inline table", function()
    if not has_toml then
      return pending("toml treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = { b = 1, a = 2 }" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "x = { a = 2, b = 1 }" }, lines_of(bufnr))
  end)

  it("sorts top-level keys above any [table] section", function()
    if not has_toml then
      return pending("toml treesitter parser not available")
    end
    local bufnr = setup_buf({ "zebra = 1", "apple = 2", "", "[s]", "y = 1" })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "apple = 2", "zebra = 1", "", "[s]", "y = 1" }, lines_of(bufnr))
  end)

  it("sorts the keys of a [table] section, keeping the header", function()
    if not has_toml then
      return pending("toml treesitter parser not available")
    end
    local bufnr = setup_buf({ "[s]", "b = 1", "a = 2" })
    set_cursor(1, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "[s]", "a = 2", "b = 1" }, lines_of(bufnr))
  end)

  it("does not drag a between-section comment into the middle on sort", function()
    if not has_toml then
      return pending("toml treesitter parser not available")
    end
    local bufnr = setup_buf({ "[a]", "x = 1", "w = 2", "# next section", "[b]", "z = 3" })
    set_cursor(1, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "[a]", "w = 2", "x = 1", "# next section", "[b]", "z = 3" }, lines_of(bufnr))
  end)

  it("sorts an array and carries a comment with its key", function()
    if not has_toml then
      return pending("toml treesitter parser not available")
    end
    local bufnr = setup_buf({ "[s]", "# doc b", "b = 1", "a = 2" })
    set_cursor(2, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "[s]", "a = 2", "# doc b", "b = 1" }, lines_of(bufnr))
  end)
end)
