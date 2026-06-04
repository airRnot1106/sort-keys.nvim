-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- Gleam buffer: record construction, function-call labels, custom-type
-- fields, positional-pin, comment-attach, and deep recursion.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "gleam"
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

describe("gleam end-to-end via :SortKeys", function()
  local has_gleam

  before_each(function()
    has_gleam = ts.has_parser("gleam")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("record construction", function()
    it("sorts labelled arguments by label", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "pub fn m() {", '  Pet(name: "N", cuteness: 10, age: 3)', "}" })
      set_cursor(bufnr, 1, 6)
      vim.cmd("SortKeys")
      assert.same(
        { "pub fn m() {", '  Pet(age: 3, cuteness: 10, name: "N")', "}" },
        lines_of(bufnr)
      )
    end)
  end)

  describe("mixed positional + labelled", function()
    it("keeps the positional argument first and sorts the labelled ones", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "pub fn m() {", "  f(1, zebra: 2, apple: 3)", "}" })
      set_cursor(bufnr, 1, 6)
      vim.cmd("SortKeys")
      assert.same({ "pub fn m() {", "  f(1, apple: 3, zebra: 2)", "}" }, lines_of(bufnr))
    end)
  end)

  describe("record update", function()
    it("sorts the labelled fields and leaves the spread in place", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "pub fn m() {", "  Pet(..base, zed: 1, apple: 2)", "}" })
      set_cursor(bufnr, 1, 14)
      vim.cmd("SortKeys")
      assert.same({ "pub fn m() {", "  Pet(..base, apple: 2, zed: 1)", "}" }, lines_of(bufnr))
    end)
  end)

  describe("case record pattern", function()
    it("sorts labelled pattern fields by label", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local bufnr =
        setup_buf({ "pub fn m() {", "  case x {", "    Foo(zed: 1, apple: 2) -> 0", "  }", "}" })
      set_cursor(bufnr, 2, 8)
      vim.cmd("SortKeys")
      assert.same(
        { "pub fn m() {", "  case x {", "    Foo(apple: 2, zed: 1) -> 0", "  }", "}" },
        lines_of(bufnr)
      )
    end)
  end)

  describe("custom type fields", function()
    it("sorts constructor fields by label", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local bufnr =
        setup_buf({ "pub type Cat {", "  Cat(name: String, age: Int, active: Bool)", "}" })
      set_cursor(bufnr, 1, 6)
      vim.cmd("SortKeys")
      assert.same(
        { "pub type Cat {", "  Cat(active: Bool, age: Int, name: String)", "}" },
        lines_of(bufnr)
      )
    end)
  end)

  describe("comment attachment", function()
    it("keeps a leading comment with its argument after a reorder", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "pub fn m() {",
        "  Pet(",
        "    // keep banana",
        "    banana: 2,",
        "    apple: 1,",
        "  )",
        "}",
      })
      set_cursor(bufnr, 3, 4)
      vim.cmd("SortKeys")
      assert.same({
        "pub fn m() {",
        "  Pet(",
        "    apple: 1,",
        "    // keep banana",
        "    banana: 2,",
        "  )",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("deep recursion", function()
    it("sorts the outer argument list and recurses into a nested record", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "pub fn m() {", "  Foo(z: 1, inner: Bar(y: 1, x: 2))", "}" })
      set_cursor(bufnr, 1, 6)
      vim.cmd("DeepSortKeys")
      assert.same({ "pub fn m() {", "  Foo(inner: Bar(x: 2, y: 1), z: 1)", "}" }, lines_of(bufnr))
    end)
  end)
end)
