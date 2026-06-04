-- Smoke-level cover of the full :SortKeys pipeline on a real typescript
-- buffer. TypeScript reuses javascript_builder because tree-sitter-typescript
-- inherits the object / pair / array node shapes from tree-sitter-javascript;
-- these cases pin the wiring (filetype → builder routing) and check that
-- TS-only syntactic constructs (type annotations on declarations, `as`
-- expressions on values) flow through transparently.

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

local function set_cursor(bufnr, row, col)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(win, { row + 1, col })
  return bufnr
end

describe("typescript end-to-end via :SortKeys", function()
  local has_ts

  before_each(function()
    has_ts = ts.has_parser("typescript")

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
      if not has_ts then
        pending("typescript treesitter parser not available")
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
        if not has_ts then
          pending("typescript treesitter parser not available")
          return
        end
        local bufnr = setup_buf({ "const o = { b: 2, a: 1, c: 3 };" })
        set_cursor(bufnr, 0, 2)
        vim.cmd("SortKeys")
        assert.equals("const o = { a: 1, b: 2, c: 3 };", lines_of(bufnr)[1])
      end
    )

    it("sorts a variable declaration carrying a type annotation", function()
      -- The `: Record<string, number>` lives outside the object literal, so
      -- the object literal itself sorts independently of the annotation.
      if not has_ts then
        pending("typescript treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "const o: Record<string, number> = { b: 2, a: 1 };" })
      set_cursor(bufnr, 0, 38)
      vim.cmd("SortKeys")
      assert.equals("const o: Record<string, number> = { a: 1, b: 2 };", lines_of(bufnr)[1])
    end)

    it("sorts a pair whose value is an `as` expression", function()
      -- `2 as number` parses as `as_expression`; it lives inside the value
      -- subtree so the pair-level classifier never sees it.
      if not has_ts then
        pending("typescript treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "const o = { b: 2 as number, a: 1 };" })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.equals("const o = { a: 1, b: 2 as number };", lines_of(bufnr)[1])
    end)
  end)

  describe("array literal", function()
    it("sorts elements lexicographically by their text", function()
      if not has_ts then
        pending("typescript treesitter parser not available")
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
      if not has_ts then
        pending("typescript treesitter parser not available")
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
      if not has_ts then
        pending("typescript treesitter parser not available")
        return
      end
      -- A spread is order-sensitive, so it fences: {c, a} before it sort to
      -- a, c and {b} after it stays put — no pair crosses `...rest`.
      local bufnr = setup_buf({ "const o = { c: 3, a: 1, ...rest, b: 2 };" })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.equals("const o = { a: 1, c: 3, ...rest, b: 2 };", lines_of(bufnr)[1])
    end)
  end)
end)
