-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- Elixir buffer: atom-shorthand map, arrow map, keyword list, struct,
-- comment-attach (leading + same-line trailing), and deep recursion.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "elixir"
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

describe("elixir end-to-end via :SortKeys", function()
  local has_elixir

  before_each(function()
    has_elixir = ts.has_parser("elixir")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("atom-shorthand map", function()
    it("sorts pairs by their colon-stripped key", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "%{banana: 2, apple: 1, cherry: 3}" })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.same({ "%{apple: 1, banana: 2, cherry: 3}" }, lines_of(bufnr))
    end)
  end)

  describe("arrow map", function()
    it("sorts string keys, stripping their quotes for comparison", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ '%{"zed" => 1, "apple" => 2}' })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.same({ '%{"apple" => 2, "zed" => 1}' }, lines_of(bufnr))
    end)
  end)

  describe("keyword list", function()
    it("sorts options by key", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "opts = [timeout: 5, backoff: 1, retries: 3]" })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.same({ "opts = [backoff: 1, retries: 3, timeout: 5]" }, lines_of(bufnr))
    end)
  end)

  describe("struct", function()
    it("sorts struct fields by key", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ '%Foo{name: "x", age: 1, active: true}' })
      set_cursor(bufnr, 0, 6)
      vim.cmd("SortKeys")
      assert.same({ '%Foo{active: true, age: 1, name: "x"}' }, lines_of(bufnr))
    end)
  end)

  describe("comment attachment", function()
    it("keeps a leading comment with its pair and a trailing comment in place", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "%{",
        "  # keeps banana",
        "  banana: 2,",
        "  apple: 1 # same-line",
        "}",
      })
      set_cursor(bufnr, 2, 2)
      vim.cmd("SortKeys")
      assert.same({
        "%{",
        "  apple: 1, # same-line",
        "  # keeps banana",
        "  banana: 2",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("deep recursion", function()
    it("sorts the outer container and recurses into a nested map value", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "%{outer: %{z: 1, a: 2}, alpha: 1}" })
      set_cursor(bufnr, 0, 4)
      vim.cmd("DeepSortKeys")
      assert.same({ "%{alpha: 1, outer: %{a: 2, z: 1}}" }, lines_of(bufnr))
    end)
  end)
end)
