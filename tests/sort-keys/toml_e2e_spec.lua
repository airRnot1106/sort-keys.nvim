-- Smoke-level cover of the full :SortKeys pipeline on a real toml buffer:
-- inline table, inline array, [section] standard table, [[array_of_tables]]
-- block, document-root pseudo container, dotted key, and comment_attach.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "toml"
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

describe("toml end-to-end via :SortKeys", function()
  local has_toml

  before_each(function()
    has_toml = ts.has_parser("toml")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("inline table", function()
    it("sorts bare keys ascending", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "x = { b = 2, a = 1, c = 3 }" })
      set_cursor(bufnr, 0, 8)
      vim.cmd("SortKeys")
      assert.equals("x = { a = 1, b = 2, c = 3 }", lines_of(bufnr)[1])
    end)
  end)

  describe("inline array", function()
    it("sorts string elements by their surface text", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ 'x = ["c", "a", "b"]' })
      set_cursor(bufnr, 0, 5)
      vim.cmd("SortKeys")
      assert.equals('x = ["a", "b", "c"]', lines_of(bufnr)[1])
    end)
  end)

  describe("[section] standard table", function()
    it("sorts pairs ascending with newline separator preserved", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "[package]",
        'name = "demo"',
        'version = "1.0"',
        'authors = ["a"]',
      })
      set_cursor(bufnr, 1, 0)
      vim.cmd("SortKeys")
      assert.same({
        "[package]",
        'authors = ["a"]',
        'name = "demo"',
        'version = "1.0"',
      }, lines_of(bufnr))
    end)
  end)

  describe("[[array_of_tables]]", function()
    it("only reorders pairs inside the [[bin]] block the cursor sits in", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "[[bin]]",
        'path = "src/main.rs"',
        'name = "main"',
        "",
        "[[bin]]",
        'path = "src/bin/helper.rs"',
        'name = "helper"',
      })
      set_cursor(bufnr, 1, 0)
      vim.cmd("SortKeys")
      assert.same({
        "[[bin]]",
        'name = "main"',
        'path = "src/main.rs"',
        "",
        "[[bin]]",
        'path = "src/bin/helper.rs"',
        'name = "helper"',
      }, lines_of(bufnr))
    end)
  end)

  describe("root-level pair group (pseudo container)", function()
    it("sorts the document-direct pairs above the first section header", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        'version = "1"',
        'title = "demo"',
        "",
        "[package]",
        'name = "x"',
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      assert.same({
        'title = "demo"',
        'version = "1"',
        "",
        "[package]",
        'name = "x"',
      }, lines_of(bufnr))
    end)
  end)

  describe("dotted key", function()
    it("treats `a.b.c = v` as a single sortable entry keyed by the dotted text", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "[s]",
        'z = "w"',
        'a.b.c = "v"',
      })
      set_cursor(bufnr, 1, 0)
      vim.cmd("SortKeys")
      assert.same({
        "[s]",
        'a.b.c = "v"',
        'z = "w"',
      }, lines_of(bufnr))
    end)
  end)

  describe("comments travel with their entry", function()
    it("keeps a leading `# comment` glued to the pair it documents", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "[s]",
        "# leading for b",
        'b = "2"',
        "# leading for a",
        'a = "1"',
      })
      set_cursor(bufnr, 1, 0)
      vim.cmd("SortKeys")
      assert.same({
        "[s]",
        "# leading for a",
        'a = "1"',
        "# leading for b",
        'b = "2"',
      }, lines_of(bufnr))
    end)
  end)
end)
