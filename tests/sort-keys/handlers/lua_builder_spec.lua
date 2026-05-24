-- Pins the Outline-boundary contract of lua_builder. Lua's `table_constructor`
-- is one AST node for both object-like and array-like tables, so the builder
-- decides container kind dynamically from entry shapes (all-positional → array;
-- otherwise → object with positional fields pinned). These cases nail that
-- contract plus the four field shapes (bare / bracket-string / bracket-computed
-- / positional) and the comment_attach delegation.

local ts = require("tests.support.treesitter")

describe("sort-keys.handlers.lua_builder", function()
  local builder
  local has_lua

  before_each(function()
    package.loaded["sort-keys.handlers.lua_builder"] = nil
    builder = require("sort-keys.handlers.lua_builder")
    has_lua = ts.has_parser("lua")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "lua"
    return bufnr
  end

  local lua_query = [[
((table_constructor) @sortkeys.container)
((field)            @sortkeys.entry)
((comment)          @sortkeys.comment)
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

  local function build_at(bufnr, row, col, t)
    return builder.build(bufnr, { kind = "cursor", pos = { row, col } }, {
      filetype = "lua",
      query_text = lua_query,
      options = t or options_for(),
    })
  end

  local function entries_by_key(outline)
    local out = {}
    for _, e in ipairs(outline.entries) do
      out[e.sort_key] = e
    end
    return out
  end

  describe("object-like table_constructor", function()
    it("returns an Outline of kind='object' with sort_keys from bare identifiers", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "local t = { b = 2, a = 1 }" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals(",", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
      local by = entries_by_key(outline)
      assert.is_not_nil(by["a"])
      assert.is_not_nil(by["b"])
      assert.is_true(by["a"].movable)
      assert.is_true(by["b"].movable)
    end)

    it("normalizes bracket-string keys via key_normalize.lua", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "local t = { [\"b\"] = 2, ['a'] = 1 }" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      local by = entries_by_key(outline)
      assert.is_not_nil(by["a"])
      assert.is_not_nil(by["b"])
    end)
  end)

  describe("array-like table_constructor", function()
    it("returns an Outline of kind='array' when every field is positional", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "local t = { 3, 1, 2 }" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.equals(3, #outline.entries)
    end)
  end)

  describe("positional fields whose value is a bare identifier", function()
    it('treats `{ "a", ident, "c" }` as all-positional → kind=\'array\'', function()
      -- Regression: an identifier-only field has just ONE named child (the
      -- value); a bare-key field has TWO (key + value). The classifier must
      -- distinguish by named_child_count, not by the type of child(0), or
      -- positional identifiers get misclassified as keyed.
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'local t = { "a", ident, "c" }' })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.equals(3, #outline.entries)
      for _, e in ipairs(outline.entries) do
        assert.is_true(e.movable)
      end
    end)
  end)

  describe("mixed table_constructor", function()
    it("classifies as object and pins positional fields", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      -- A keyed entry coexists with positional entries; reordering the
      -- positional ones would change their implicit array indices, so they
      -- must stay put while the keyed ones sort around them.
      local bufnr = make_buf({ "local t = { a = 1, 2, 3, b = 4 }" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      local movable_count = 0
      local pinned_count = 0
      for _, e in ipairs(outline.entries) do
        if e.movable then
          movable_count = movable_count + 1
        else
          pinned_count = pinned_count + 1
        end
      end
      assert.equals(2, movable_count) -- a, b
      assert.equals(2, pinned_count) -- 2, 3
    end)
  end)

  describe("bracket-computed keys stay pinned", function()
    it("marks `[expr] = v` with non-string expression as movable=false", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      -- Reordering past a runtime-computed key can change semantic meaning
      -- (the expression may depend on side effects), so the entry pins.
      local bufnr = make_buf({ "local t = { [k] = 1, a = 2 }" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      local movable_count = 0
      local pinned_count = 0
      for _, e in ipairs(outline.entries) do
        if e.movable then
          movable_count = movable_count + 1
        else
          pinned_count = pinned_count + 1
        end
      end
      assert.equals(1, movable_count)
      assert.equals(1, pinned_count)
    end)
  end)

  describe("delegation to comment_attach", function()
    it(
      "expands an entry's range to swallow a leading comment when comment_aware is true",
      function()
        if not has_lua then
          pending("lua treesitter parser not available")
          return
        end
        local bufnr = make_buf({
          "local t = {",
          "  -- leading for b",
          "  b = 2,",
          "  a = 1,",
          "}",
        })
        local outline = build_at(bufnr, 0, 11)
        assert.is_not_nil(outline)
        local by = entries_by_key(outline)
        local b_entry = by["b"]
        assert.is_not_nil(b_entry)
        -- Range row should now start at the comment line (row 1) rather than
        -- the `b = 2` line (row 2).
        assert.equals(1, b_entry.range[1])
      end
    )

    it("leaves entry ranges untouched when comment_aware is false", function()
      if not has_lua then
        pending("lua treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "local t = {",
        "  -- leading for b",
        "  b = 2,",
        "  a = 1,",
        "}",
      })
      local outline = build_at(bufnr, 0, 11, options_for({ comment_aware = false }))
      assert.is_not_nil(outline)
      local by = entries_by_key(outline)
      assert.equals(2, by["b"].range[1])
    end)
  end)
end)
