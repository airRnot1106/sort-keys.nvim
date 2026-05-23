-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- yaml buffer: block_mapping sort, block_sequence sort, flow containers,
-- leading-comment travel, and anchor-pinned entries. The fine-grained policy
-- rules already live under tests/sort-keys/core/.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  -- tree-sitter-yaml's container ranges include a phantom trailing newline,
  -- so the buffer must own that line for `nvim_buf_get_text` to read up to
  -- it. Real .yaml files always end with a newline.
  local with_eof = vim.list_extend(vim.list_extend({}, lines), { "" })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, with_eof)
  vim.bo[bufnr].filetype = "yaml"
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

describe("yaml end-to-end via :SortKeys", function()
  local has_yaml

  before_each(function()
    has_yaml = ts.has_parser("yaml")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("block_mapping", function()
    it("sorts top-level keys ascending without re-emitting separators", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "b: 2", "a: 1", "c: 3" })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      -- setup_buf appends an EOF newline; the assertion mirrors that.
      assert.same({ "a: 1", "b: 2", "c: 3", "" }, lines_of(bufnr))
    end)

    it("preserves indentation when sorting a nested block_mapping with :DeepSortKeys", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "outer:",
        "  b: 2",
        "  a: 1",
      })
      set_cursor(bufnr, 1, 2)
      vim.cmd("SortKeys")
      assert.same({
        "outer:",
        "  a: 1",
        "  b: 2",
        "",
      }, lines_of(bufnr))
    end)
  end)

  describe("block_sequence", function()
    it("sorts elements by their text content", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "- c", "- a", "- b" })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      assert.same({ "- a", "- b", "- c", "" }, lines_of(bufnr))
    end)
  end)

  describe("flow containers", function()
    it("sorts a flow_mapping with `,` separator and no trailing comma", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "root: { b: 2, a: 1 }" })
      set_cursor(bufnr, 0, 10)
      vim.cmd("SortKeys")
      assert.equals("root: { a: 1, b: 2 }", lines_of(bufnr)[1])
    end)

    it("sorts a flow_sequence with `,` separator", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "root: [c, a, b]" })
      set_cursor(bufnr, 0, 10)
      vim.cmd("SortKeys")
      assert.equals("root: [a, b, c]", lines_of(bufnr)[1])
    end)
  end)

  describe("comments travel with their entry", function()
    it("keeps a leading line comment glued to the pair it documents", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "# leading for b",
        "b: 2",
        "# leading for a",
        "a: 1",
      })
      set_cursor(bufnr, 1, 0)
      vim.cmd("SortKeys")
      assert.same({
        "# leading for a",
        "a: 1",
        "# leading for b",
        "b: 2",
        "",
      }, lines_of(bufnr))
    end)
  end)

  describe("visual partial sort", function()
    -- YAML's indent-based structure means a typical `V`-mode line selection
    -- starts at column 0 — outside any indented inner container. The
    -- builder must still pick the inner container when the selection
    -- overlaps its entries.
    it("sorts entries of a nested block_mapping selected by full-line ranges", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "outer:",
        "  c: 3",
        "  a: 1",
        "  b: 2",
        "  z: 4",
      })
      -- Select rows 1..3 (the c/a/b pairs) at full-line extent; the
      -- z pair on row 4 is outside the selection and must stay put.
      -- col = vim.v.maxcol simulates V-line mode's "end of line" mark.
      vim.fn.setpos("'<", { bufnr, 2, 1, 0 })
      vim.fn.setpos("'>", { bufnr, 4, vim.v.maxcol, 0 })
      vim.cmd("'<,'>SortKeys")
      assert.same({
        "outer:",
        "  a: 1",
        "  b: 2",
        "  c: 3",
        "  z: 4",
        "",
      }, lines_of(bufnr))
    end)
  end)

  describe("anchor safety", function()
    it("keeps an anchor-bearing entry at its original position while the rest reorders", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      -- "a" carries an anchor and must stay at slot 1; the rest (b, c, d)
      -- reorder among the movable slots — by ascending key that means slot
      -- 2 = b, slot 3 = c, slot 4 = d.
      local bufnr = setup_buf({
        "a: &anchor 1",
        "d: 4",
        "c: 3",
        "b: 2",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      assert.same({
        "a: &anchor 1",
        "b: 2",
        "c: 3",
        "d: 4",
        "",
      }, lines_of(bufnr))
    end)
  end)
end)
