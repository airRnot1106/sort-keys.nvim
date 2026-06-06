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
    -- The cursor must sit on a property to pick the property level; on the node
    -- name it would sort sibling nodes instead.
    set_cursor(1, 2)
    vim.cmd("SortKeys")
    assert.are.same({ "node \\", "  a=1 \\", "  b=2" }, lines_of(bufnr))
  end)

  -- Like JSON, the cursor picks the "key" level: on a node name it sorts the
  -- sibling nodes by name; on a property it sorts that node's properties.
  it("sorts sibling nodes by name when the cursor is on a node", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    local bufnr = setup_buf({ "zebra 1", "apple 2", "mango 3" })
    set_cursor(0, 1)
    vim.cmd("SortKeys")
    assert.are.same({ "apple 2", "mango 3", "zebra 1" }, lines_of(bufnr))
  end)

  it("sorts sibling nodes inside a children block", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    local bufnr = setup_buf({ "pkg {", "  zebra 1", "  apple 2", "}" })
    set_cursor(1, 3)
    vim.cmd("SortKeys")
    assert.are.same({ "pkg {", "  apple 2", "  zebra 1", "}" }, lines_of(bufnr))
  end)

  it("keeps `;` node terminators slot-bound when reordering nodes", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    -- The `;` lives inside each node's range; without slot-binding it, sorting
    -- would merge `c 1; a 2` into one node `a 2 c 1;`.
    local bufnr = setup_buf({ "c 1; a 2; b 3" })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "a 2; b 3; c 1" }, lines_of(bufnr))
  end)

  it("sorts the outer nodes while leaving a nested block untouched", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    local bufnr = setup_buf({ "c 1", "a 2", "b {", "  y 1", "  x 2", "}" })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ "a 2", "b {", "  y 1", "  x 2", "}", "c 1" }, lines_of(bufnr))
  end)

  it("deep-sorts nested children blocks", function()
    if not has_kdl then
      return pending("kdl treesitter parser not available")
    end
    local bufnr = setup_buf({ "c 1", "a 2", "b {", "  y 1", "  x 2", "}" })
    set_cursor(0, 0)
    vim.cmd("DeepSortKeys")
    assert.are.same({ "a 2", "b {", "  x 2", "  y 1", "}", "c 1" }, lines_of(bufnr))
  end)
end)
