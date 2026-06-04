-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- Ruby buffer: hash literal, hash-rocket keys, keyword args (paren-less),
-- positional / splat pin, comment-attach, and deep recursion.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "ruby"
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

describe("ruby end-to-end via :SortKeys", function()
  local has_ruby

  before_each(function()
    has_ruby = ts.has_parser("ruby")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("hash literal", function()
    it("sorts pairs by symbol key", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "h = { banana: 2, apple: 1, cherry: 3 }" })
      set_cursor(bufnr, 0, 8)
      vim.cmd("SortKeys")
      assert.same({ "h = { apple: 1, banana: 2, cherry: 3 }" }, lines_of(bufnr))
    end)

    it("sorts hash-rocket string keys, stripping quotes for comparison", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ 'h = { "zed" => 1, "apple" => 2 }' })
      set_cursor(bufnr, 0, 8)
      vim.cmd("SortKeys")
      assert.same({ 'h = { "apple" => 2, "zed" => 1 }' }, lines_of(bufnr))
    end)
  end)

  describe("keyword arguments", function()
    it("keeps a leading positional symbol and sorts the keyword pairs", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "validates :name, presence: true, length: 3" })
      set_cursor(bufnr, 0, 18)
      vim.cmd("SortKeys")
      assert.same({ "validates :name, length: 3, presence: true" }, lines_of(bufnr))
    end)
  end)

  describe("double-splat fences the sort", function()
    it("keeps `**defaults` first and sorts the remaining pairs", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "h = { **defaults, zed: 1, apple: 2 }" })
      set_cursor(bufnr, 0, 20)
      vim.cmd("SortKeys")
      assert.same({ "h = { **defaults, apple: 2, zed: 1 }" }, lines_of(bufnr))
    end)

    it("does not let a pair cross a mid-hash `**` splat (override order)", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      -- `z: 3` is before the splat (the splat may override it); `a: 1` is after
      -- (it overrides the splat). Sorting must not swap which side they're on,
      -- so each single-element segment stays put.
      local bufnr = setup_buf({ "h = { z: 3, **opts, a: 1 }" })
      set_cursor(bufnr, 0, 8)
      vim.cmd("SortKeys")
      assert.same({ "h = { z: 3, **opts, a: 1 }" }, lines_of(bufnr))
    end)
  end)

  describe("case/in hash pattern", function()
    it("sorts keyword_pattern members by label", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "case obj", "in { name:, age:, id: }", "  1", "end" })
      set_cursor(bufnr, 1, 6)
      vim.cmd("SortKeys")
      assert.same({ "case obj", "in { age:, id:, name: }", "  1", "end" }, lines_of(bufnr))
    end)
  end)

  describe("comment attachment", function()
    it("keeps a leading comment with its pair after a reorder", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "h = {",
        "  # keep banana",
        "  banana: 2,",
        "  apple: 1,",
        "}",
      })
      set_cursor(bufnr, 2, 2)
      vim.cmd("SortKeys")
      assert.same({
        "h = {",
        "  apple: 1,",
        "  # keep banana",
        "  banana: 2,",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("deep recursion", function()
    it("sorts the outer hash and recurses into a nested hash", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "h = { z: 1, a: { y: 1, x: 2 } }" })
      set_cursor(bufnr, 0, 8)
      vim.cmd("DeepSortKeys")
      assert.same({ "h = { a: { x: 2, y: 1 }, z: 1 }" }, lines_of(bufnr))
    end)
  end)
end)
