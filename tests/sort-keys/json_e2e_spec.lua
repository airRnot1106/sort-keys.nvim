-- Skipped on environments without the JSON treesitter parser; without it the
-- e2e path can never reach the builder, so failing here would just be noise.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "json"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(bufnr, row, col)
  local win = vim.api.nvim_get_current_win()
  -- nvim_win_set_cursor uses 1-indexed row.
  vim.api.nvim_win_set_cursor(win, { row + 1, col })
  return bufnr
end

describe("json end-to-end via :SortKeys / :DeepSortKeys", function()
  local has_json
  local notifies

  local original_notify

  before_each(function()
    has_json = ts.has_parser("json")

    -- Make sure the plugin is loaded and registries are fresh.
    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")

    notifies = {}
    original_notify = vim.notify
    vim.notify = function(msg, level, opts)
      table.insert(notifies, { msg = msg, level = level, opts = opts })
    end
  end)

  after_each(function()
    vim.notify = original_notify
  end)

  describe("normal-mode :SortKeys on a JSON object", function()
    it("sorts the keys ascending and rewrites the buffer", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ '{ "c": 3, "a": 1, "b": 2 }' })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.equals('{ "a": 1, "b": 2, "c": 3 }', lines_of(bufnr)[1])
    end)

    it("reverses with bang (`!`)", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ '{ "a": 1, "b": 2, "c": 3 }' })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys!")
      assert.equals('{ "c": 3, "b": 2, "a": 1 }', lines_of(bufnr)[1])
    end)
  end)

  describe("normal-mode :SortKeys on a JSON array", function()
    it("sorts elements lexicographically by their text content", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ '[ "c", "a", "b" ]' })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.equals('[ "a", "b", "c" ]', lines_of(bufnr)[1])
    end)
  end)

  describe("visual — partial sort working example", function()
    it("{c:3, a:1, b:2} with first two pairs selected → {a:1, c:3, b:2}", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      -- Source buffer: { "c": 3, "a": 1, "b": 2 }
      -- pair ranges (0-indexed cols):
      --   "c": 3    @ cols 2..7
      --   "a": 1    @ cols 10..15
      --   "b": 2    @ cols 18..23
      local bufnr = setup_buf({ '{ "c": 3, "a": 1, "b": 2 }' })

      -- Drive visual selection through Neovim's `'<` / `'>` marks so the
      -- command-level mode detection is exercised; cover cols 2..15
      -- (pair 1 + pair 2).
      vim.fn.setpos("'<", { bufnr, 1, 3, 0 }) -- 1-indexed line, 1-indexed col 3 == col 2 (0-indexed)
      vim.fn.setpos("'>", { bufnr, 1, 16, 0 })
      vim.cmd("'<,'>SortKeys")

      assert.equals('{ "a": 1, "c": 3, "b": 2 }', lines_of(bufnr)[1])
    end)
  end)

  describe(":DeepSortKeys", function()
    it("recursively sorts nested object values", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ '{ "b": { "y": 2, "x": 1 }, "a": { "n": 4, "m": 3 } }' })
      set_cursor(bufnr, 0, 1)
      vim.cmd("DeepSortKeys")
      assert.equals('{ "a": { "m": 3, "n": 4 }, "b": { "x": 1, "y": 2 } }', lines_of(bufnr)[1])
    end)

    it("plain :SortKeys leaves nested objects untouched", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ '{ "b": { "y": 2, "x": 1 }, "a": { "n": 4, "m": 3 } }' })
      set_cursor(bufnr, 0, 1)
      vim.cmd("SortKeys")
      assert.equals('{ "a": { "n": 4, "m": 3 }, "b": { "y": 2, "x": 1 } }', lines_of(bufnr)[1])
    end)
  end)

  -- Regression cover: earlier suites were single-line-heavy, which let a bug
  -- that collapsed newlines / indentation between sorted entries slip
  -- through. These cases pin the slot-separator-preservation contract on
  -- pretty-printed JSON.
  describe("multi-line format preservation on :SortKeys (object)", function()
    it("preserves newlines and indentation between sorted entries", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "{",
        '  "c": 3,',
        '  "a": 1,',
        '  "b": 2',
        "}",
      })
      -- Cursor inside the outer object but outside any inner container.
      set_cursor(bufnr, 1, 0)
      vim.cmd("SortKeys")
      assert.same({
        "{",
        '  "a": 1,',
        '  "b": 2,',
        '  "c": 3',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("multi-line format preservation on :SortKeys (array)", function()
    it("preserves newlines and indentation between sorted elements", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "[",
        '  "c",',
        '  "a",',
        '  "b"',
        "]",
      })
      set_cursor(bufnr, 1, 0)
      vim.cmd("SortKeys")
      assert.same({
        "[",
        '  "a",',
        '  "b",',
        '  "c"',
        "]",
      }, lines_of(bufnr))
    end)
  end)

  describe("multi-line format preservation on :DeepSortKeys (nested object)", function()
    it("preserves indentation at every depth after deep sort", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "{",
        '  "b": {',
        '    "y": 2,',
        '    "x": 1',
        "  },",
        '  "a": {',
        '    "n": 4,',
        '    "m": 3',
        "  }",
        "}",
      })
      set_cursor(bufnr, 1, 0)
      vim.cmd("DeepSortKeys")
      assert.same({
        "{",
        '  "a": {',
        '    "m": 3,',
        '    "n": 4',
        "  },",
        '  "b": {',
        '    "x": 1,',
        '    "y": 2',
        "  }",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("multi-line format preservation on :DeepSortKeys (nested array)", function()
    it("preserves the outer line layout while inner elements get sorted", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      -- Outer entries already lex-ordered ("[3, 1, 2]" < "[9, 7, 8]"), so the
      -- outer line layout must stay intact while each inner array is sorted.
      local bufnr = setup_buf({
        "[",
        "  [3, 1, 2],",
        "  [9, 7, 8]",
        "]",
      })
      set_cursor(bufnr, 1, 0)
      vim.cmd("DeepSortKeys")
      assert.same({
        "[",
        "  [1, 2, 3],",
        "  [7, 8, 9]",
        "]",
      }, lines_of(bufnr))
    end)
  end)

  describe("multi-line format preservation on Visual partial sort (object)", function()
    it("reorders only the selected entries and leaves the fixed entry untouched", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      -- Buffer (0-indexed):
      --   0: '{'
      --   1: '  "c": 3,'     <- pair range cols 2..8
      --   2: '  "a": 1,'     <- pair range cols 2..8
      --   3: '  "b": 2'      <- pair range cols 2..8 (NOT covered by selection)
      --   4: '}'
      local bufnr = setup_buf({
        "{",
        '  "c": 3,',
        '  "a": 1,',
        '  "b": 2',
        "}",
      })

      -- Visual selection covers entries `"c": 3` and `"a": 1` only.
      -- 1-indexed line/col; (line 2, col 3) == 0-indexed (1, 2);
      --                    (line 3, col 9) == 0-indexed (2, 8).
      vim.fn.setpos("'<", { bufnr, 2, 3, 0 })
      vim.fn.setpos("'>", { bufnr, 3, 9, 0 })
      vim.cmd("'<,'>SortKeys")

      assert.same({
        "{",
        '  "a": 1,',
        '  "c": 3,',
        '  "b": 2',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("multi-line format preservation on Visual partial sort (array)", function()
    it("reorders only the selected elements and leaves the fixed element untouched", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      -- Buffer (0-indexed):
      --   0: '['
      --   1: '  "c",'        <- element range cols 2..5
      --   2: '  "a",'        <- element range cols 2..5
      --   3: '  "b"'         <- element range cols 2..5 (NOT covered)
      --   4: ']'
      local bufnr = setup_buf({
        "[",
        '  "c",',
        '  "a",',
        '  "b"',
        "]",
      })

      vim.fn.setpos("'<", { bufnr, 2, 3, 0 })
      vim.fn.setpos("'>", { bufnr, 3, 6, 0 })
      vim.cmd("'<,'>SortKeys")

      assert.same({
        "[",
        '  "a",',
        '  "c",',
        '  "b"',
        "]",
      }, lines_of(bufnr))
    end)
  end)

  describe("error paths", function()
    it("notifies the user when the cursor is not on a sortable container", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ '"plain string"' })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.is_true(#notifies >= 1)
      assert.equals('"plain string"', lines_of(bufnr)[1])
    end)

    it("notifies the user when there is no handler for the filetype", function()
      local bufnr = setup_buf({ '{ "c": 3, "a": 1 }' })
      vim.bo[bufnr].filetype = "python"
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.is_true(#notifies >= 1)
    end)
  end)
end)
