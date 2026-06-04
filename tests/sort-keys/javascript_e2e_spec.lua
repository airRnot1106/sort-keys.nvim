-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- javascript buffer: object literal sort, array literal sort, leading
-- comment travel, spread pinned in place.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "javascript"
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

describe("javascript end-to-end via :SortKeys", function()
  local has_js

  before_each(function()
    has_js = ts.has_parser("javascript")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("object literal", function()
    it("sorts top-level keys ascending", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "const o = { b: 2, a: 1, c: 3 };" })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.equals("const o = { a: 1, b: 2, c: 3 };", lines_of(bufnr)[1])
    end)

    it(
      "sorts when the cursor sits on the `const ... =` prefix, left of the opening brace",
      function()
        -- The object literal starts further right on the same line; the cursor
        -- picker resolves the container by row, not by strict containment.
        if not has_js then
          pending("javascript treesitter parser not available")
          return
        end
        local bufnr = setup_buf({ "const o = { b: 2, a: 1, c: 3 };" })
        set_cursor(bufnr, 0, 2)
        vim.cmd("SortKeys")
        assert.equals("const o = { a: 1, b: 2, c: 3 };", lines_of(bufnr)[1])
      end
    )
  end)

  describe("array literal", function()
    it("sorts elements lexicographically by their text", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ 'const a = ["c", "a", "b"];' })
      set_cursor(bufnr, 0, 11)
      vim.cmd("SortKeys")
      assert.equals('const a = ["a", "b", "c"];', lines_of(bufnr)[1])
    end)
  end)

  describe("comments travel with their entry", function()
    it("keeps a leading line comment glued to the pair it documents", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "const o = {",
        "  // leading for b",
        "  b: 2,",
        "  // leading for a",
        "  a: 1,",
        "};",
      })
      set_cursor(bufnr, 0, 11)
      vim.cmd("SortKeys")
      assert.same({
        "const o = {",
        "  // leading for a",
        "  a: 1,",
        "  // leading for b",
        "  b: 2,",
        "};",
      }, lines_of(bufnr))
    end)
  end)

  describe("spread element fences the sort", function()
    it("sorts each side of a spread independently, never across it", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      -- A spread is order-sensitive (a later key overrides an earlier one), so
      -- it fences: the pairs before it {c, a} sort among themselves → a, c, and
      -- the pair after it {b} stays after. `b` must NOT jump ahead of `...rest`
      -- and `c` must NOT fall behind it — that would change which key wins.
      local bufnr = setup_buf({ "const o = { c: 3, a: 1, ...rest, b: 2 };" })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.equals("const o = { a: 1, c: 3, ...rest, b: 2 };", lines_of(bufnr)[1])
    end)
  end)
end)
