-- TypeScript rides on the JavaScript query + normalizer; this smoke-checks the
-- wiring (parser_lang = "typescript", pin/fence) end to end.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "typescript"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("typescript end-to-end", function()
  local has_ts

  before_each(function()
    has_ts = ts.has_parser("typescript")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts object keys", function()
    if not has_ts then
      return pending("typescript treesitter parser not available")
    end
    local bufnr = setup_buf({ "const o = { b: 1, a: 2 };" })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ "const o = { a: 2, b: 1 };" }, lines_of(bufnr))
  end)

  it("fences a spread and recurses with :DeepSortKeys", function()
    if not has_ts then
      return pending("typescript treesitter parser not available")
    end
    local bufnr = setup_buf({
      "const o = {",
      "  ...base,",
      "  b: { y: 1, x: 2 },",
      "  a: 3,",
      "};",
    })
    set_cursor(1, 2)
    vim.cmd("DeepSortKeys")
    assert.are.same({
      "const o = {",
      "  ...base,",
      "  a: 3,",
      "  b: { x: 2, y: 1 },",
      "};",
    }, lines_of(bufnr))
  end)
end)
