-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- kdl buffer: a children block, the document root, deep recursion, and
-- comment_attach (leading + same-line trailing). Each spec sets up its own
-- buffer; the cursor placement targets the specific container being sorted.

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

local function set_cursor(bufnr, row, col)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(win, { row + 1, col })
  return bufnr
end

describe("kdl end-to-end via :SortKeys", function()
  local has_kdl

  before_each(function()
    has_kdl = ts.has_parser("kdl")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("children block", function()
    it("sorts the child nodes of a `{ }` block by node name", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "config {",
        '  version "1"',
        '  name "demo"',
        "  age 2",
        "}",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("SortKeys")
      assert.same({
        "config {",
        "  age 2",
        '  name "demo"',
        '  version "1"',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("document root", function()
    it("sorts the file's top-level nodes by node name", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        'title "Hello"',
        'author "Alex"',
        "bookmarks 1",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      assert.same({
        'author "Alex"',
        "bookmarks 1",
        'title "Hello"',
      }, lines_of(bufnr))
    end)
  end)

  describe(":DeepSortKeys", function()
    it("recurses into a nested children block before sorting the outer nodes", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "z {",
        "  y 2",
        "  x 1",
        "}",
        "a 1",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("DeepSortKeys")
      assert.same({
        "a 1",
        "z {",
        "  x 1",
        "  y 2",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("comments travel with their entry", function()
    it("keeps a leading line comment and a same-line trailing comment with their node", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "config {",
        "  // leading for b",
        "  b 2 // trailing for b",
        "  // leading for a",
        "  a 1",
        "}",
      })
      set_cursor(bufnr, 2, 2)
      vim.cmd("SortKeys")
      assert.same({
        "config {",
        "  // leading for a",
        "  a 1",
        "  // leading for b",
        "  b 2 // trailing for b",
        "}",
      }, lines_of(bufnr))
    end)
  end)
end)
