-- Smoke-level cover of the full :SortKeys pipeline on a real lua buffer:
-- object-style table sort, array-style table sort, mixed (positional pinned),
-- and comment-attach via the declarative comment_aware path.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "lua"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(bufnr, row, col)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(win, { row + 1, col })
  return bufnr
end

describe("lua end-to-end via :SortKeys", function()
  local has_lua

  before_each(function()
    has_lua = ts.has_parser("lua")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("object-style table", function()
    it("sorts bare-key fields ascending", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "local t = { b = 2, a = 1, c = 3 }" })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.equals("local t = { a = 1, b = 2, c = 3 }", lines_of(bufnr)[1])
    end)

    it("sorts when the cursor sits on the `local t =` prefix, left of the opening brace", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "local t = { b = 2, a = 1, c = 3 }" })
      set_cursor(bufnr, 0, 2)
      vim.cmd("SortKeys")
      assert.equals("local t = { a = 1, b = 2, c = 3 }", lines_of(bufnr)[1])
    end)
  end)

  describe("array-style table", function()
    it("sorts positional elements lexicographically by their surface text", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ 'local t = { "c", "a", "b" }' })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.equals('local t = { "a", "b", "c" }', lines_of(bufnr)[1])
    end)
  end)

  describe("mixed table", function()
    it("sorts keyed entries and leaves positional entries pinned in place", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      -- Slots: 1=b (movable), 2=42 (positional, pin), 3=a (movable). The
      -- movable slots receive sort_keys a, b → slot 1=a, slot 3=b; the
      -- positional `42` stays at slot 2.
      local bufnr = setup_buf({ "local t = { b = 2, 42, a = 1 }" })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.equals("local t = { a = 1, 42, b = 2 }", lines_of(bufnr)[1])
    end)
  end)

  describe("comments travel with their entry", function()
    it("keeps a leading line comment glued to the field it documents", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "local t = {",
        "  -- leading for b",
        "  b = 2,",
        "  -- leading for a",
        "  a = 1,",
        "}",
      })
      set_cursor(bufnr, 0, 11)
      vim.cmd("SortKeys")
      assert.same({
        "local t = {",
        "  -- leading for a",
        "  a = 1,",
        "  -- leading for b",
        "  b = 2,",
        "}",
      }, lines_of(bufnr))
    end)
  end)
end)
