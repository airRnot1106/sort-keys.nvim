local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "pkl"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("pkl end-to-end", function()
  local has_pkl

  before_each(function()
    has_pkl = ts.has_parser("pkl")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts object properties", function()
    if not has_pkl then
      return pending("pkl treesitter parser not available")
    end
    local bufnr = setup_buf({ "x {", "  b = 1", "  a = 2", "}" })
    set_cursor(1, 2)
    vim.cmd("SortKeys")
    assert.are.same({ "x {", "  a = 2", "  b = 1", "}" }, lines_of(bufnr))
  end)

  it(":DeepSortKeys recurses into a nested object body", function()
    if not has_pkl then
      return pending("pkl treesitter parser not available")
    end
    local bufnr = setup_buf({
      "x {",
      "  b = 1",
      "  a {",
      "    d = 1",
      "    c = 2",
      "  }",
      "}",
    })
    set_cursor(1, 2)
    vim.cmd("DeepSortKeys")
    assert.are.same({
      "x {",
      "  a {",
      "    c = 2",
      "    d = 1",
      "  }",
      "  b = 1",
      "}",
    }, lines_of(bufnr))
  end)
end)
