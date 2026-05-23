-- Pins the Outline-boundary contract of javascript_builder. The JS-specific
-- contracts that earn their own cases are: per-entry-kind sortability
-- (pair / shorthand / method are movable; spread / computed-key pair are
-- pinned), and key extraction from the multiple key-node shapes (bare
-- identifier, double-quoted string, single-quoted string, numeric literal).

local ts = require("tests.support.treesitter")

describe("sort-keys.handlers.declarative.javascript_builder", function()
  local builder
  local has_js

  before_each(function()
    package.loaded["sort-keys.handlers.declarative.javascript_builder"] = nil
    builder = require("sort-keys.handlers.declarative.javascript_builder")
    has_js = ts.has_parser("javascript")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "javascript"
    return bufnr
  end

  local js_query = [[
((object) @sortkeys.container (#set! sortkeys.kind "object"))
((array)  @sortkeys.container (#set! sortkeys.kind "array"))

((pair)                          @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((shorthand_property_identifier) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((spread_element)                @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((method_definition)             @sortkeys.entry (#set! sortkeys.entry_kind "pair"))

((array (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))

((comment) @sortkeys.comment)
]]

  local js_toml = {
    can_sort_object = true,
    can_sort_array = true,
    can_deep = true,
    key_quoting = "logical",
    comment_aware = true,
    mixed_key_types = false,
    structural_separator = ",",
    trailing_separator_allowed = true,
    query_file = "sort-keys.scm",
  }

  local function build_at(bufnr, row, col)
    return builder.build(bufnr, { kind = "cursor", pos = { row, col } }, {
      filetype = "javascript",
      query_text = js_query,
      toml = js_toml,
    })
  end

  local function entries_by_key(outline)
    local out = {}
    for _, e in ipairs(outline.entries) do
      out[e.sort_key] = e
    end
    return out
  end

  describe("object literal", function()
    it("returns an Outline of kind='object' with sort_keys from property_identifier", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "const o = { b: 2, a: 1 };" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals(",", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
      local by = entries_by_key(outline)
      assert.is_not_nil(by["a"])
      assert.is_not_nil(by["b"])
    end)

    it("normalizes quoted string keys via key_normalize.js", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "const o = { \"b\": 2, 'a': 1 };" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      local by = entries_by_key(outline)
      assert.is_not_nil(by["a"])
      assert.is_not_nil(by["b"])
    end)

    it("normalizes numeric-literal keys to their surface text", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "const o = { 2: 'b', 1: 'a' };" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      local by = entries_by_key(outline)
      assert.is_not_nil(by["1"])
      assert.is_not_nil(by["2"])
    end)
  end)

  describe("array literal", function()
    it("returns an Outline of kind='array' with one entry per element", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "const a = [3, 1, 2];" })
      local outline = build_at(bufnr, 0, 11)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.equals(3, #outline.entries)
    end)
  end)

  describe("shorthand property", function()
    it("treats `{ a, b }` shorthand as movable pairs keyed by the identifier", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "const o = { b, a };" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      local by = entries_by_key(outline)
      assert.is_true(by["a"].movable)
      assert.is_true(by["b"].movable)
    end)
  end)

  describe("method definition", function()
    it("uses the method's property_identifier as the sort_key and remains movable", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "const o = {",
        "  b() { return 1; },",
        "  a() { return 2; },",
        "};",
      })
      local outline = build_at(bufnr, 0, 11)
      assert.is_not_nil(outline)
      local by = entries_by_key(outline)
      assert.is_true(by["a"].movable)
      assert.is_true(by["b"].movable)
    end)
  end)

  describe("non-sortable entries stay pinned", function()
    it("marks a spread_element movable=false", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      -- spread order is semantically significant (override precedence), so
      -- moving the spread past adjacent pairs must be forbidden.
      local bufnr = make_buf({ "const o = { a: 1, ...rest, b: 2 };" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      local spread = nil
      for _, e in ipairs(outline.entries) do
        if e.movable == false then
          spread = e
        end
      end
      assert.is_not_nil(spread)
    end)

    it("marks a computed-key pair movable=false", function()
      if not has_js then
        pending("javascript treesitter parser not available")
        return
      end
      -- `[expr]:` is evaluated at runtime; sorting by surface text is at
      -- best lossy, so the entry stays pinned.
      local bufnr = make_buf({ "const o = { [k]: 1, a: 2 };" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      local movable_count = 0
      local fixed_count = 0
      for _, e in ipairs(outline.entries) do
        if e.movable then
          movable_count = movable_count + 1
        else
          fixed_count = fixed_count + 1
        end
      end
      assert.equals(1, movable_count) -- a
      assert.equals(1, fixed_count) -- [k]
    end)
  end)
end)
