-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- pkl buffer: module-level properties, object body, mapping, listing, deep
-- recursion, and comment_attach. Each spec sets up its own buffer; the cursor
-- placement targets the specific container being sorted.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "pkl"
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

describe("pkl end-to-end via :SortKeys", function()
  local has_pkl

  before_each(function()
    has_pkl = ts.has_parser("pkl")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("module-level properties", function()
    it("sorts the file's top-level properties by their identifier", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        'name = "Pkl"',
        "attendants = 100",
        "isInteractive = true",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      assert.same({
        "attendants = 100",
        "isInteractive = true",
        'name = "Pkl"',
      }, lines_of(bufnr))
    end)

    it("leaves the module header untouched while sorting the properties below it", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        'amends "base.pkl"',
        "",
        "b = 2",
        "a = 1",
      })
      set_cursor(bufnr, 2, 0)
      vim.cmd("SortKeys")
      assert.same({
        'amends "base.pkl"',
        "",
        "a = 1",
        "b = 2",
      }, lines_of(bufnr))
    end)
  end)

  describe("object body", function()
    it("sorts properties inside an object body by identifier", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "bird {",
        '  name = "pigeon"',
        '  diet = "seeds"',
        "  age = 2",
        "}",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("SortKeys")
      assert.same({
        "bird {",
        "  age = 2",
        '  diet = "seeds"',
        '  name = "pigeon"',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("mapping", function()
    it("sorts mapping entries by their bracketed string key", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "m = new Mapping {",
        '  ["c"] = 3',
        '  ["a"] = 1',
        '  ["b"] = 2',
        "}",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("SortKeys")
      assert.same({
        "m = new Mapping {",
        '  ["a"] = 1',
        '  ["b"] = 2',
        '  ["c"] = 3',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("listing", function()
    it("sorts listing elements by their surface text", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "l = new Listing {",
        '  "c"',
        '  "a"',
        '  "b"',
        "}",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("SortKeys")
      assert.same({
        "l = new Listing {",
        '  "a"',
        '  "b"',
        '  "c"',
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe(":DeepSortKeys", function()
    it("recurses into a nested object body before sorting the outer properties", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        'z = "last"',
        "a {",
        "  y = 2",
        "  x = 1",
        "}",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("DeepSortKeys")
      assert.same({
        "a {",
        "  x = 1",
        "  y = 2",
        "}",
        'z = "last"',
      }, lines_of(bufnr))
    end)
  end)

  describe("comments travel with their entry", function()
    it(
      "keeps a leading line comment and a same-line trailing comment with their property",
      function()
        if not has_pkl then
          pending("pkl treesitter parser not available")
          return
        end
        local bufnr = setup_buf({
          "// doc for b",
          "b = 2 // trailing for b",
          "a = 1",
        })
        set_cursor(bufnr, 0, 0)
        vim.cmd("SortKeys")
        assert.same({
          "a = 1",
          "// doc for b",
          "b = 2 // trailing for b",
        }, lines_of(bufnr))
      end
    )
  end)
end)
