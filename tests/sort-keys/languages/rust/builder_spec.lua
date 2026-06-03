-- Pins the Outline-boundary contract of rust_builder.
--
-- Rust has three sortable container shapes — all name-keyed:
--   field_declaration_list (struct definition body)
--   field_initializer_list (struct literal body)
--   use_list               (grouped use imports)
-- `enum_variant_list` / `match_block` / `array_expression` / `tuple_expression`
-- are intentionally outside the contract: this spec asserts they are NOT
-- picked as containers by the builder.
--
-- Two Rust-specific delegations matter here:
--   1. `attribute_item` (e.g. `#[serde(...)]`) is routed to comment_attach
--      via @sortkeys.comment, so an attribute preceding a field expands
--      that field's range to swallow it.
--   2. `base_field_initializer` (`..base`) is classified movable=false so
--      the struct-update tail stays after the explicit fields.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.rust.builder", function()
  local builder
  local has_rust

  before_each(function()
    package.loaded["sort-keys.languages.rust.builder"] = nil
    builder = require("sort-keys.languages.rust.builder")
    has_rust = ts.has_parser("rust")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "rust"
    return bufnr
  end

  local rust_query = [[
((field_declaration_list) @sortkeys.container (#set! sortkeys.kind "object"))
((field_initializer_list) @sortkeys.container (#set! sortkeys.kind "object"))
((use_list)               @sortkeys.container (#set! sortkeys.kind "array"))

((field_declaration
   name: (field_identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((field_initializer
   field: (field_identifier) @sortkeys.key
   value: (_) @sortkeys.value) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((shorthand_field_initializer
   (identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((base_field_initializer) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((use_list (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

((line_comment) @sortkeys.comment)
((block_comment) @sortkeys.comment)
((attribute_item) @sortkeys.comment)
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
      filetype = "rust",
      query_text = rust_query,
      options = t or options_for(),
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
    it("returns kind='object' with sort_keys from each field's identifier", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "struct Foo { b: u32, a: u32 }" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "a", "b" }, sorted_keys(outline))
      for _, e in ipairs(outline.entries) do
        assert.equals("pair", e.kind)
        assert.is_true(e.movable)
      end
    end)

    it("normalizes `r#type` raw-identifier field name to `type` for sorting", function()
      -- `r#` is a syntactic escape, not part of the field's semantic name.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "struct Foo { r#type: u32, b: u32 }" })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.same({ "b", "type" }, sorted_keys(outline))
    end)
  end)

  describe("field_initializer_list (struct literal)", function()
    it("returns kind='object' with sort_keys from each initializer's field", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "fn f() { let _ = Foo { b: 2, a: 1 }; }",
      })
      local outline = build_at(bufnr, 0, 22)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "a", "b" }, sorted_keys(outline))
    end)

    it("treats a shorthand initializer (`Foo { a, b }`) as a movable pair", function()
      -- The shorthand uses the bare identifier as both surface key and value;
      -- it must classify as movable=true so it reorders with the other fields.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "fn f(x: u32, y: u32) { let _ = Foo { y, x }; }",
      })
      local outline = build_at(bufnr, 0, 36)
      assert.is_not_nil(outline)
      assert.equals(2, #outline.entries)
      for _, e in ipairs(outline.entries) do
        assert.is_true(e.movable)
      end
      assert.same({ "x", "y" }, sorted_keys(outline))
    end)

    it("classifies `..base` (base_field_initializer) as movable=false", function()
      -- The grammar requires `..base` to be the tail of the field list, so
      -- reordering past it would yield invalid syntax — pin it.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "fn f() { let _ = Foo { b: 2, a: 1, ..base }; }",
      })
      local outline = build_at(bufnr, 0, 22)
      assert.is_not_nil(outline)
      local pinned = 0
      for _, e in ipairs(outline.entries) do
        if not e.movable then
          pinned = pinned + 1
        end
      end
      assert.equals(1, pinned)
    end)
  end)

  describe("use_list (grouped imports)", function()
    it("returns kind='array' with sort_keys from each member's surface text", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "use std::collections::{HashMap, BTreeMap, HashSet};",
      })
      local outline = build_at(bufnr, 0, 25)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.same({ "BTreeMap", "HashMap", "HashSet" }, sorted_keys(outline))
    end)

    it("excludes inline block-comment bytes from a use_list element's sort_key", function()
      -- `vim.treesitter.get_node_text` over a `use_as_clause` like
      -- `A /* x */ as Aliased` returns the source slice over the whole range,
      -- including the comment bytes. The sort_key must collapse those out so
      -- adding or removing an inline comment doesn't silently reorder the
      -- import list.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "use foo::{B, A /* note */ as Aliased};",
      })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      assert.equals(2, #outline.entries)
      local keys = sorted_keys(outline)
      for _, k in ipairs(keys) do
        assert.is_nil(k:find("/%*", 1), "sort_key still contains block-comment bytes: " .. k)
      end
    end)

    it("strips a mid-path `r#` raw-identifier prefix in a scoped use_list entry", function()
      -- `r#` is a syntactic escape; the same logical import `foo::bar` may
      -- be written `foo::r#bar` if the bare name collides with a keyword.
      -- Both spellings must collapse to the same sort_key, otherwise edits
      -- to the source spelling silently reorder the import list.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "use foo::{x, r#type, bar::r#type};",
      })
      local outline = build_at(bufnr, 0, 12)
      assert.is_not_nil(outline)
      local keys = sorted_keys(outline)
      -- Each `r#type` occurrence should appear as `type` in its sort_key,
      -- not retained mid-path as `r#type`.
      for _, k in ipairs(keys) do
        assert.is_nil(k:find("r#", 1, true), "sort_key still contains `r#`: " .. k)
      end
    end)
  end)

  describe("non-sortable Rust containers are deliberately ignored", function()
    it("does not pick a `match_block` (semantic pattern order)", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "fn f(x: i32) -> i32 {",
        "    match x {",
        "        2 => 20,",
        "        1 => 10,",
        "        _ => 0,",
        "    }",
        "}",
      })
      -- Cursor inside the match body must NOT yield a sortable outline.
      local outline = build_at(bufnr, 2, 8)
      assert.is_nil(outline)
    end)

    it("does not pick an `array_expression` (positional indexing)", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "const A: [u32; 3] = [3, 1, 2];" })
      local outline = build_at(bufnr, 0, 21)
      assert.is_nil(outline)
    end)

    it("does not pick a `tuple_expression`", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "const T: (u32, u32) = (2, 1);" })
      local outline = build_at(bufnr, 0, 23)
      assert.is_nil(outline)
    end)

    it("does not pick an `enum_variant_list`", function()
      -- Variant order can affect derived `Ord` and implicit discriminants.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "enum E { B, A, C }" })
      local outline = build_at(bufnr, 0, 9)
      assert.is_nil(outline)
    end)
  end)

  describe("delegation to comment_attach", function()
    it("expands a field's range to swallow a leading line comment", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "struct Foo {",
        "    // leading for a",
        "    a: u32,",
        "}",
      })
      local outline = build_at(bufnr, 0, 12, options_for({ comment_aware = true }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      -- After attach the entry's range must start at the comment row (1),
      -- not the bare field row (2).
      assert.equals(1, outline.entries[1].range[1])
    end)

    it("expands a field's range to swallow a leading `#[serde(...)]` attribute", function()
      -- This is the Rust-specific delegation: the attribute_item is captured
      -- as @sortkeys.comment so it travels with the next field when sorted.
      -- Without this, sorting `b` above `a` would leave `#[serde(rename=...)]`
      -- attached to the wrong field — a silent semantic break.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "struct Foo {",
        '    #[serde(rename = "B")]',
        "    b: u32,",
        "}",
      })
      local outline = build_at(bufnr, 0, 12, options_for({ comment_aware = true }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      assert.equals(1, outline.entries[1].range[1])
    end)

    it("expands a field's range to swallow a leading `///` doc comment", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "struct Foo {",
        "    /// doc for a",
        "    a: u32,",
        "}",
      })
      local outline = build_at(bufnr, 0, 12, options_for({ comment_aware = true }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      assert.equals(1, outline.entries[1].range[1])
    end)

    it("leaves field ranges anchored at the field when comment_aware is false", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "struct Foo {",
        "    // leading for a",
        "    a: u32,",
        "}",
      })
      local outline = build_at(bufnr, 0, 12, options_for({ comment_aware = false }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      assert.equals(2, outline.entries[1].range[1])
    end)
  end)

  describe("deep recursion linkage", function()
    it("hangs a nested struct-literal value off its outer field_initializer's child", function()
      -- The outer field_initializer's value is `struct_expression`, not a
      -- container itself; the builder must walk one level into the value
      -- to find the inner field_initializer_list.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "fn f() { let _ = Outer { inner: Inner { b: 2, a: 1 } }; }",
      })
      local outline = build_at(bufnr, 0, 24)
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      local child = outline.entries[1].child
      assert.is_not_nil(child)
      assert.equals("object", child.kind)
      assert.same({ "a", "b" }, sorted_keys(child))
    end)
  end)

  describe("return value arity contract", function()
    it("returns exactly one value (Outline | nil)", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "struct Foo { a: u32 }" })
      assert.equals(1, select("#", build_at(bufnr, 0, 12)))
    end)
  end)
end)
