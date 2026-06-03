-- Pins the Outline-boundary contract of go_builder.
--
-- Three container shapes share the AST scaffolding:
--   field_declaration_list (struct definition body)
--   literal_value          (struct OR map literal body — slice / array
--                            bodies use the same node type but the builder
--                            filters them out via the "no keyed_element
--                            children" predicate)
--   import_spec_list       (parenthesized import group)
--
-- The spec asserts both the inclusion side (struct / map / import all
-- yield a sortable Outline) and the exclusion side (slice literal /
-- positional struct literal are dropped before pick_innermost).

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.go.builder", function()
  local builder
  local has_go

  before_each(function()
    package.loaded["sort-keys.languages.go.builder"] = nil
    builder = require("sort-keys.languages.go.builder")
    has_go = ts.has_parser("go")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "go"
    return bufnr
  end

  local go_query = [[
((field_declaration_list) @sortkeys.container (#set! sortkeys.kind "object"))
((literal_value)          @sortkeys.container (#set! sortkeys.kind "object"))
((import_spec_list)       @sortkeys.container (#set! sortkeys.kind "array"))

((field_declaration
   (field_identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((keyed_element) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((import_spec) @sortkeys.entry
 (#set! sortkeys.entry_kind "element"))

((comment) @sortkeys.comment)
]]

  local function options_for(overrides)
    local base = {
      can_sort_object = true,
      can_sort_array = true,
      can_deep = true,
      key_quoting = "logical",
      comment_aware = true,
      mixed_key_types = true,
      structural_separator = ",",
      trailing_separator_allowed = true,
      query_file = "sort-keys.scm",
    }
    for k, v in pairs(overrides or {}) do
      base[k] = v
    end
    return base
  end

  local function build_at(bufnr, row, col, opts)
    return builder.build(bufnr, { kind = "cursor", pos = { row, col } }, {
      filetype = "go",
      query_text = go_query,
      options = opts or options_for(),
    })
  end

  local function sorted_keys(outline)
    local out = {}
    for _, e in ipairs(outline.entries) do
      out[#out + 1] = e.sort_key
    end
    table.sort(out)
    return out
  end

  describe("field_declaration_list (struct definition)", function()
    it("returns kind='object' with sort_keys from each field identifier", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "type Foo struct {",
        "  Bar string",
        "  Apple int",
        "}",
      })
      local outline = build_at(bufnr, 1, 16)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "Apple", "Bar" }, sorted_keys(outline))
    end)

    it("uses the empty inter-entry separator (struct fields are newline-gapped)", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "type Foo struct {",
        "  A int",
        "  B int",
        "}",
      })
      local outline = build_at(bufnr, 1, 16)
      assert.is_not_nil(outline)
      assert.equals("", outline.structural_separator)
    end)
  end)

  describe("literal_value (struct or map composite literal)", function()
    it("treats a struct literal body as kind='object' with keyed_element entries", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "func f() {",
        "  _ = Foo{Bar: 1, Apple: 2}",
        "}",
      })
      local outline = build_at(bufnr, 2, 12)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "Apple", "Bar" }, sorted_keys(outline))
    end)

    it("treats a map literal body as kind='object', stripping string-key quotes", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "func f() {",
        '  _ = map[string]int{"b": 2, "a": 1}',
        "}",
      })
      local outline = build_at(bufnr, 2, 22)
      assert.is_not_nil(outline)
      assert.same({ "a", "b" }, sorted_keys(outline))
    end)

    it("uses `,` as the inter-entry separator for composite-literal bodies", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "func f() {",
        "  _ = Foo{A: 1, B: 2}",
        "}",
      })
      local outline = build_at(bufnr, 2, 12)
      assert.is_not_nil(outline)
      assert.equals(",", outline.structural_separator)
    end)

    it("does NOT pick a slice composite literal (positional)", function()
      -- `[]int{1, 2, 3}` shares the `literal_value` AST node with struct /
      -- map literals but its children are `literal_element` rather than
      -- `keyed_element`; the builder must drop it before pick_innermost.
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "func f() {",
        "  _ = []int{3, 1, 2}",
        "}",
      })
      local outline = build_at(bufnr, 2, 13)
      assert.is_nil(outline)
    end)
  end)

  describe("import_spec_list", function()
    it("returns kind='array' with sort_keys from each import path", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "import (",
        '  "os"',
        '  "fmt"',
        ")",
      })
      local outline = build_at(bufnr, 1, 7)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.same({ "fmt", "os" }, sorted_keys(outline))
    end)

    it("sorts an aliased import by its path, not by the alias", function()
      -- gofmt sorts by path; alias is documentation, not ordering.
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "import (",
        '  zfmt "fmt"',
        '  "os"',
        ")",
      })
      local outline = build_at(bufnr, 1, 7)
      assert.is_not_nil(outline)
      assert.same({ "fmt", "os" }, sorted_keys(outline))
    end)
  end)

  describe("non-sortable Go containers are deliberately ignored", function()
    it("does not pick an expression_switch_statement", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "func f(x int) {",
        "  switch x {",
        '  case 2: println("two")',
        '  case 1: println("one")',
        "  }",
        "}",
      })
      local outline = build_at(bufnr, 2, 9)
      assert.is_nil(outline)
    end)

    it("does not pick a const_declaration block", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "const (",
        "  A = 1",
        "  B = 2",
        ")",
      })
      local outline = build_at(bufnr, 1, 7)
      assert.is_nil(outline)
    end)
  end)

  describe("delegation to comment_attach", function()
    it("expands a field's range to swallow a leading line comment", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "type Foo struct {",
        "  // leading for A",
        "  A int",
        "}",
      })
      local outline = build_at(bufnr, 1, 16, options_for({ comment_aware = true }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      -- Comment row is 2; absorbed entry must start at row 2 instead of 3.
      assert.equals(2, outline.entries[1].range[1])
    end)
  end)

  describe("deep recursion linkage", function()
    it("hangs a nested struct-literal value off its outer keyed_element", function()
      if not has_go then
        pending("go treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "package main",
        "func f() {",
        "  _ = Outer{Inner: Inner{B: 2, A: 1}}",
        "}",
      })
      local outline = build_at(bufnr, 2, 12)
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      local child = outline.entries[1].child
      assert.is_not_nil(child)
      assert.equals("object", child.kind)
      assert.same({ "A", "B" }, sorted_keys(child))
    end)
  end)
end)
