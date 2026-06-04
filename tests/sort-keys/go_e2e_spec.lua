-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- Go buffer: struct definition, struct literal, map literal, import block,
-- per-container separator policy, comment-attach (leading + same-line
-- trailing), deep recursion.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "go"
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

describe("go end-to-end via :SortKeys", function()
  local has_go

  before_each(function()
    has_go = ts.has_parser("go")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("struct definition", function()
    it("sorts fields by identifier, preserving newline gaps", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "package main",
        "",
        "type Foo struct {",
        "\tVersion string",
        "\tName    string",
        "\tAge     int",
        "}",
      })
      set_cursor(bufnr, 3, 4)
      vim.cmd("SortKeys")
      assert.same({
        "package main",
        "",
        "type Foo struct {",
        "\tAge     int",
        "\tName    string",
        "\tVersion string",
        "}",
      }, lines_of(bufnr))
    end)

    -- A grouped declaration (`Name, Age string`) is one field_declaration node;
    -- the query matches it once per identifier. The whole group sorts as a
    -- single unit keyed by its first identifier — and must not crash on the
    -- duplicate match.
    it("treats a multi-identifier field declaration as one sortable unit", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "package main",
        "",
        "type Foo struct {",
        "\tZed       int",
        "\tName, Age string",
        "}",
      })
      set_cursor(bufnr, 3, 4)
      vim.cmd("SortKeys")
      assert.same({
        "package main",
        "",
        "type Foo struct {",
        "\tName, Age string",
        "\tZed       int",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("struct literal", function()
    it("sorts keyed_element entries on a multi-line composite literal", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "package main",
        "",
        "func make() Foo {",
        "\treturn Foo{",
        '\t\tVersion: "1",',
        '\t\tName:    "demo",',
        "\t\tAge:     2,",
        "\t}",
        "}",
      })
      set_cursor(bufnr, 4, 8)
      vim.cmd("SortKeys")
      assert.same({
        "package main",
        "",
        "func make() Foo {",
        "\treturn Foo{",
        "\t\tAge:     2,",
        '\t\tName:    "demo",',
        '\t\tVersion: "1",',
        "\t}",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("map literal", function()
    it("sorts string keys, stripping their quotes for comparison", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "package main",
        "",
        "func make() map[string]int {",
        "\treturn map[string]int{",
        '\t\t"version": 1,',
        '\t\t"name":    2,',
        '\t\t"age":     3,',
        "\t}",
        "}",
      })
      set_cursor(bufnr, 4, 8)
      vim.cmd("SortKeys")
      assert.same({
        "package main",
        "",
        "func make() map[string]int {",
        "\treturn map[string]int{",
        '\t\t"age":     3,',
        '\t\t"name":    2,',
        '\t\t"version": 1,',
        "\t}",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("import block", function()
    it("sorts import_spec entries by their path text", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "package main",
        "",
        "import (",
        '\t"os"',
        '\t"fmt"',
        '\t"strings"',
        ")",
      })
      set_cursor(bufnr, 3, 1)
      vim.cmd("SortKeys")
      assert.same({
        "package main",
        "",
        "import (",
        '\t"fmt"',
        '\t"os"',
        '\t"strings"',
        ")",
      }, lines_of(bufnr))
    end)

    it("sorts an aliased import by its path rather than its alias", function()
      -- `zfmt "fmt"` sorts as `fmt`, before `"os"`.
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "package main",
        "",
        "import (",
        '\tzfmt "fmt"',
        '\t"os"',
        ")",
      })
      set_cursor(bufnr, 3, 1)
      vim.cmd("SortKeys")
      assert.same({
        "package main",
        "",
        "import (",
        '\tzfmt "fmt"',
        '\t"os"',
        ")",
      }, lines_of(bufnr))
    end)
  end)

  describe("slice literal stays put", function()
    it("falls through to the no-sortable-structure path on `[]int{...}`", function()
      -- A slice composite literal shares the `literal_value` AST node with
      -- struct / map literals, but the builder drops it because its entries
      -- are positional `literal_element` rather than `keyed_element`. The
      -- buffer must end up byte-identical to source.
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "package main",
        "",
        "func make() []int {",
        "\treturn []int{3, 1, 2}",
        "}",
      })
      set_cursor(bufnr, 3, 14)
      vim.cmd("SortKeys")
      assert.same({
        "package main",
        "",
        "func make() []int {",
        "\treturn []int{3, 1, 2}",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe(":DeepSortKeys", function()
    it("recurses into a nested struct-literal value before sorting the outer fields", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "package main",
        "",
        "func make() Outer {",
        "\treturn Outer{",
        "\t\tZ: Inner{",
        "\t\t\tY: 2,",
        "\t\t\tX: 1,",
        "\t\t},",
        "\t\tA: 1,",
        "\t}",
        "}",
      })
      set_cursor(bufnr, 3, 8)
      vim.cmd("DeepSortKeys")
      assert.same({
        "package main",
        "",
        "func make() Outer {",
        "\treturn Outer{",
        "\t\tA: 1,",
        "\t\tZ: Inner{",
        "\t\t\tX: 1,",
        "\t\t\tY: 2,",
        "\t\t},",
        "\t}",
        "}",
      }, lines_of(bufnr))
    end)
  end)
end)
