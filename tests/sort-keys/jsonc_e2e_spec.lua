-- The jsonc handler reuses the json treesitter parser (its grammar accepts
-- JSONC comments as `(comment)` nodes), so the parser-availability guard
-- below checks for `json`, not `jsonc`.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "jsonc"
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

describe("jsonc end-to-end via :SortKeys", function()
  local has_jsonc

  before_each(function()
    has_jsonc = ts.has_parser("json")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("comment-free JSONC behaves identically to JSON", function()
    it("sorts the keys of a JSONC object ascending", function()
      if not has_jsonc then
        pending("json treesitter parser not available (jsonc reuses it)")
        return
      end
      local bufnr = setup_buf({ '{ "c": 3, "a": 1, "b": 2 }' })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.equals('{ "a": 1, "b": 2, "c": 3 }', lines_of(bufnr)[1])
    end)

    it("sorts the elements of a JSONC array lexicographically", function()
      if not has_jsonc then
        pending("json treesitter parser not available (jsonc reuses it)")
        return
      end
      local bufnr = setup_buf({ '[ "c", "a", "b" ]' })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.equals('[ "a", "b", "c" ]', lines_of(bufnr)[1])
    end)
  end)

  describe("separator normalization across reorder", function()
    it("re-emits the separator when a trailing comment absorbed the original comma", function()
      if not has_jsonc then
        pending("json treesitter parser not available (jsonc reuses it)")
        return
      end
      local bufnr = setup_buf({
        "{",
        "  // L for b",
        '  "b": 2, /* T for b */',
        "  // L for a",
        '  "a": 1',
        "}",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      assert.same({
        "{",
        "  // L for a",
        '  "a": 1,',
        "  // L for b",
        '  "b": 2, /* T for b */',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("array elements with same-line trailing comments", function()
    -- The wildcard array-entry query `(array (_) @sortkeys.entry)` admits
    -- comment children as entries; the collect_matches dedup pass drops
    -- any candidate whose node was also captured as a comment. Without
    -- that drop, the comment is sorted as data AND attached as a comment,
    -- comment_attach's range expansion pushes a real entry past it on the
    -- same row, and the applier crashes on the resulting `start_col >
    -- end_col` inter-entry gap.
    it("sorts string elements while keeping each trailing comment with its element", function()
      if not has_jsonc then
        pending("json treesitter parser not available (jsonc reuses it)")
        return
      end
      local bufnr = setup_buf({
        "[",
        '  "c", // T-c',
        '  "a", // T-a',
        '  "b"',
        "]",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      -- `a` is now non-last and already had its `,` in front of `// T-a`,
      -- so the separator stays there. `b` has no trailing comment so its
      -- separator is appended as usual. `c` becomes the last element, but
      -- JSONC permits a trailing comma so its absorbed `,` stays put —
      -- the critical contract is that the comma is BEFORE `// T-c`, not
      -- buried inside the line comment.
      assert.same({
        "[",
        '  "a", // T-a',
        '  "b",',
        '  "c", // T-c',
        "]",
      }, lines_of(bufnr))
    end)
  end)

  describe("comments travel with their entry", function()
    it("keeps each leading line comment glued to the pair it documents", function()
      if not has_jsonc then
        pending("json treesitter parser not available (jsonc reuses it)")
        return
      end
      local bufnr = setup_buf({
        "{",
        "  // first comment",
        '  "b": 2,',
        "  // second comment",
        '  "a": 1',
        "}",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      assert.same({
        "{",
        "  // second comment",
        '  "a": 1,',
        "  // first comment",
        '  "b": 2',
        "}",
      }, lines_of(bufnr))
    end)
  end)
end)
