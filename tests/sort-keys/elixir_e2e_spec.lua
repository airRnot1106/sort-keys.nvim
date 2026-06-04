local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "elixir"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("elixir end-to-end", function()
  local has_ex

  before_each(function()
    has_ex = ts.has_parser("elixir")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts an atom-key map", function()
    if not has_ex then
      return pending("elixir treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = %{b: 1, a: 2}" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "x = %{a: 2, b: 1}" }, lines_of(bufnr))
  end)

  it("sorts an arrow map", function()
    if not has_ex then
      return pending("elixir treesitter parser not available")
    end
    local bufnr = setup_buf({ 'x = %{"b" => 1, "a" => 2}' })
    set_cursor(0, 8)
    vim.cmd("SortKeys")
    assert.are.same({ 'x = %{"a" => 2, "b" => 1}' }, lines_of(bufnr))
  end)

  it("sorts a keyword list", function()
    if not has_ex then
      return pending("elixir treesitter parser not available")
    end
    local bufnr = setup_buf({ "f(b: 1, a: 2)" })
    set_cursor(0, 2)
    vim.cmd("SortKeys")
    assert.are.same({ "f(a: 2, b: 1)" }, lines_of(bufnr))
  end)

  it("sorts a mixed map without dropping members", function()
    if not has_ex then
      return pending("elixir treesitter parser not available")
    end
    local bufnr = setup_buf({ 'x = %{"a" => 1, c: 3, b: 2}' })
    set_cursor(0, 8)
    vim.cmd("SortKeys")
    assert.are.same({ 'x = %{"a" => 1, b: 2, c: 3}' }, lines_of(bufnr))
  end)

  it("keeps the map-update target and sorts the updated keys", function()
    if not has_ex then
      return pending("elixir treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = %{m | c: 1, a: 2}" })
    set_cursor(0, 12)
    vim.cmd("SortKeys")
    assert.are.same({ "x = %{m | a: 2, c: 1}" }, lines_of(bufnr))
  end)

  it(":DeepSortKeys recurses into a nested map", function()
    if not has_ex then
      return pending("elixir treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = %{b: %{y: 1, x: 2}, a: 3}" })
    set_cursor(0, 6)
    vim.cmd("DeepSortKeys")
    assert.are.same({ "x = %{a: 3, b: %{x: 2, y: 1}}" }, lines_of(bufnr))
  end)
end)
