-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- python buffer: a dict literal, a list literal, deep recursion, splat
-- pinning, and comment_attach (leading + same-line trailing).

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

local function set_cursor(bufnr, row, col)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(win, { row + 1, col })
  return bufnr
end

describe("python end-to-end via :SortKeys", function()
  local has_python

  before_each(function()
    has_python = ts.has_parser("python")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("dictionary literal", function()
    it("sorts the pairs of a `{ }` dict by key text", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "d = {",
        '    "version": "1",',
        '    "name": "demo",',
        '    "age": 2,',
        "}",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("SortKeys")
      assert.same({
        "d = {",
        '    "age": 2,',
        '    "name": "demo",',
        '    "version": "1",',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("list literal", function()
    it("sorts the elements of a `[ ]` list by surface text", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "xs = [",
        '    "c",',
        '    "a",',
        '    "b",',
        "]",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("SortKeys")
      assert.same({
        "xs = [",
        '    "a",',
        '    "b",',
        '    "c",',
        "]",
      }, lines_of(bufnr))
    end)
  end)

  describe(":DeepSortKeys", function()
    it("recurses into a nested dict value before sorting the outer pairs", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "d = {",
        '    "z": {',
        '        "y": 2,',
        '        "x": 1,',
        "    },",
        '    "a": 1,',
        "}",
      })
      set_cursor(bufnr, 0, 4)
      vim.cmd("DeepSortKeys")
      assert.same({
        "d = {",
        '    "a": 1,',
        '    "z": {',
        '        "x": 1,',
        '        "y": 2,',
        "    },",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("**spread keeps its position", function()
    it("does not reorder `**defaults` past sibling pairs", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "d = {",
        "    **defaults,",
        '    "b": 2,',
        '    "a": 1,',
        "}",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("SortKeys")
      -- `**defaults` stays at index 1 (its anchor); the two pairs reorder.
      assert.same({
        "d = {",
        "    **defaults,",
        '    "a": 1,',
        '    "b": 2,',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("comments travel with their pair", function()
    it("keeps a leading line comment and a same-line trailing comment with their pair", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      -- Source-last `a` has NO trailing comma here, matching the JSONC suite's
      -- well-tested convention. With a trailing comma on the source-last
      -- entry, the container suffix carries that comma verbatim and the
      -- applier would emit it AFTER the new sorted-last entry's absorbed
      -- comment — an orthogonal applier policy issue, not a Python concern.
      local bufnr = setup_buf({
        "d = {",
        "    # leading for b",
        '    "b": 2,  # trailing for b',
        "    # leading for a",
        '    "a": 1',
        "}",
      })
      set_cursor(bufnr, 2, 4)
      vim.cmd("SortKeys")
      assert.same({
        "d = {",
        "    # leading for a",
        '    "a": 1,',
        "    # leading for b",
        '    "b": 2,  # trailing for b',
        "}",
      }, lines_of(bufnr))
    end)
  end)
end)
