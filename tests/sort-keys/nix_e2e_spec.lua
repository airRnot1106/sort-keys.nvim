local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "nix"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("nix end-to-end", function()
  local has_nix

  before_each(function()
    has_nix = ts.has_parser("nix")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("sorts attrset bindings (semicolon-separated)", function()
    if not has_nix then
      return pending("nix treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = { b = 1; a = 2; }" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "x = { a = 2; b = 1; }" }, lines_of(bufnr))
  end)

  it("pins an inherit while keyed bindings sort around it", function()
    if not has_nix then
      return pending("nix treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = { c = 1; inherit z; a = 2; }" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "x = { a = 2; inherit z; c = 1; }" }, lines_of(bufnr))
  end)

  it("pins inherit (scope) ...; (inherit_from) so it is never dropped", function()
    if not has_nix then
      return pending("nix treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = { c = 3; b = 2; inherit (pkgs) hello; a = 1; }" })
    set_cursor(0, 6)
    vim.cmd("SortKeys")
    assert.are.same({ "x = { a = 1; b = 2; inherit (pkgs) hello; c = 3; }" }, lines_of(bufnr))
  end)

  it(":DeepSortKeys recurses into a nested attrset", function()
    if not has_nix then
      return pending("nix treesitter parser not available")
    end
    local bufnr = setup_buf({ "x = { b = { d = 1; c = 2; }; a = 3; }" })
    set_cursor(0, 6)
    vim.cmd("DeepSortKeys")
    assert.are.same({ "x = { a = 3; b = { c = 2; d = 1; }; }" }, lines_of(bufnr))
  end)
end)
