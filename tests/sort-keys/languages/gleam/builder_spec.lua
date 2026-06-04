-- Pins the Outline-boundary contract of gleam_builder.
--
-- Four AST container shapes share the scaffolding:
--   arguments                  (record / function_call argument list)
--   data_constructor_arguments (custom-type constructor field list)
--   record_update_arguments    (record-update field list)
--   record_pattern_arguments   (case record-pattern field list)
--
-- The spec asserts the inclusion side (labelled args / type fields yield a
-- sortable Outline) and the exclusion side (a purely positional call is
-- dropped before pick_innermost), plus the positional-pin rule.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.gleam.builder", function()
  local builder
  local has_gleam

  before_each(function()
    package.loaded["sort-keys.languages.gleam.builder"] = nil
    builder = require("sort-keys.languages.gleam.builder")
    has_gleam = ts.has_parser("gleam")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "gleam"
    return bufnr
  end

  local gleam_query = [[
((arguments (argument label: (label))) @sortkeys.container
 (#set! sortkeys.kind "object"))
((data_constructor_arguments (data_constructor_argument label: (label))) @sortkeys.container
 (#set! sortkeys.kind "object"))
((record_update_arguments (record_update_argument label: (label))) @sortkeys.container
 (#set! sortkeys.kind "object"))
((record_pattern_arguments (record_pattern_argument label: (label))) @sortkeys.container
 (#set! sortkeys.kind "object"))
((argument) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((data_constructor_argument) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((record_update_argument) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((record_pattern_argument) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
(comment) @sortkeys.comment
]]

  local function options_for(overrides)
    local base = {
      can_sort_object = true,
      can_sort_array = false,
      can_deep = true,
      key_quoting = "logical",
      comment_aware = true,
      mixed_key_types = false,
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
      filetype = "gleam",
      query_text = gleam_query,
      options = opts or options_for(),
    })
  end

  local function keys_in_order(outline)
    local out = {}
    for _, e in ipairs(outline.entries) do
      out[#out + 1] = e.sort_key
    end
    return out
  end

  describe("record / function-call argument list", function()
    it("returns kind='object' with sort_keys from each label", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "pub fn m() {", '  Pet(name: "N", age: 3)', "}" })
      local outline = build_at(bufnr, 1, 6)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "name", "age" }, keys_in_order(outline))
    end)

    it("pins a positional argument (no label) at movable=false", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "pub fn m() {", '  f(1, name: "x")', "}" }), 1, 6)
      assert.is_not_nil(outline)
      -- The positional `1` is entry 1; it has no sort_key and must not move.
      assert.is_false(outline.entries[1].movable)
      assert.equals("", outline.entries[1].sort_key)
      assert.is_true(outline.entries[2].movable)
      assert.equals("name", outline.entries[2].sort_key)
    end)

    it("uses the comma inter-entry separator with trailing allowed", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "pub fn m() {", "  Pet(a: 1, b: 2)", "}" }), 1, 6)
      assert.is_not_nil(outline)
      assert.equals(",", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
    end)
  end)

  describe("record update / case pattern field lists", function()
    it("treats a record_update_arguments list as kind='object'", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local outline =
        build_at(make_buf({ "pub fn m() {", "  Pet(..base, zed: 1, apple: 2)", "}" }), 1, 14)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "zed", "apple" }, keys_in_order(outline))
    end)

    it("treats a record_pattern_arguments list as kind='object'", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local outline = build_at(
        make_buf({ "pub fn m() {", "  case x {", "    Foo(b: 1, a: 2) -> 0", "  }", "}" }),
        2,
        8
      )
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "b", "a" }, keys_in_order(outline))
    end)
  end)

  describe("custom-type constructor fields", function()
    it("treats data_constructor_arguments as kind='object'", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local outline =
        build_at(make_buf({ "pub type Cat {", "  Cat(name: String, age: Int)", "}" }), 1, 6)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "name", "age" }, keys_in_order(outline))
    end)
  end)

  describe("deep recursion", function()
    it("attaches a child Outline for a nested record value", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      local outline =
        build_at(make_buf({ "pub fn m() {", "  Foo(inner: Bar(b: 1, a: 2))", "}" }), 1, 6)
      assert.is_not_nil(outline)
      local inner_entry = outline.entries[1]
      assert.equals("inner", inner_entry.sort_key)
      assert.is_not_nil(inner_entry.child)
      assert.same({ "b", "a" }, keys_in_order(inner_entry.child))
    end)
  end)

  describe("non-sortable structures", function()
    it("returns nil for a purely positional call", function()
      if not has_gleam then
        pending("gleam treesitter parser not available")
        return
      end
      assert.is_nil(build_at(make_buf({ "pub fn m() {", "  g(1, 2)", "}" }), 1, 6))
    end)
  end)
end)
