-- Pins the Outline-boundary contract of ruby_builder.
--
-- Three AST container shapes share the scaffolding:
--   hash          (a `{ ... }` literal)
--   argument_list (a method call's argument list)
--   hash_pattern  (a `case`/`in` hash pattern)
--
-- The spec asserts the inclusion side (keyword pairs / patterns yield a
-- sortable Outline), the exclusion side (a positional-only call / array is
-- dropped), and the positional / splat pin rule.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.ruby.builder", function()
  local builder
  local has_ruby

  before_each(function()
    package.loaded["sort-keys.languages.ruby.builder"] = nil
    builder = require("sort-keys.languages.ruby.builder")
    has_ruby = ts.has_parser("ruby")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "ruby"
    return bufnr
  end

  local ruby_query = [[
((hash (pair)) @sortkeys.container (#set! sortkeys.kind "object"))
((argument_list (pair)) @sortkeys.container (#set! sortkeys.kind "object"))
((hash_pattern (keyword_pattern)) @sortkeys.container (#set! sortkeys.kind "object"))
((hash (_) @sortkeys.entry) (#set! sortkeys.entry_kind "pair"))
((argument_list (_) @sortkeys.entry) (#set! sortkeys.entry_kind "pair"))
((hash_pattern (_) @sortkeys.entry) (#set! sortkeys.entry_kind "pair"))
(comment) @sortkeys.comment
]]

  local function options_for(overrides)
    local base = {
      can_sort_object = true,
      can_sort_array = false,
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
      filetype = "ruby",
      query_text = ruby_query,
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

  describe("hash literal", function()
    it("returns kind='object' with sort_keys from each pair key", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "h = { b: 2, a: 1 }" }), 0, 8)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "b", "a" }, keys_in_order(outline))
    end)

    it("normalizes hash-rocket string and symbol keys", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ 'h = { "zed" => 1, :alpha => 2 }' }), 0, 8)
      assert.is_not_nil(outline)
      assert.same({ "zed", "alpha" }, keys_in_order(outline))
    end)

    it("pins a `**` splat (no key) at movable=false", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "h = { **defaults, a: 1 }" }), 0, 8)
      assert.is_not_nil(outline)
      assert.is_false(outline.entries[1].movable)
      assert.equals("", outline.entries[1].sort_key)
      assert.is_true(outline.entries[2].movable)
      assert.equals("a", outline.entries[2].sort_key)
    end)

    it("uses the comma inter-entry separator with trailing allowed", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "h = { a: 1, b: 2 }" }), 0, 8)
      assert.is_not_nil(outline)
      assert.equals(",", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
    end)
  end)

  describe("method argument list", function()
    it("pins a positional argument and sorts the keyword pairs", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "validates :name, presence: true, length: 3" }), 0, 18)
      assert.is_not_nil(outline)
      assert.is_false(outline.entries[1].movable)
      assert.equals("presence", outline.entries[2].sort_key)
      assert.equals("length", outline.entries[3].sort_key)
    end)
  end)

  describe("case/in hash pattern", function()
    it("treats a hash_pattern as kind='object' keyed by keyword_pattern labels", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "case obj", "in { name:, age: }", "  1", "end" }), 1, 6)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "name", "age" }, keys_in_order(outline))
    end)
  end)

  describe("deep recursion", function()
    it("attaches a child Outline for a nested hash value", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "h = { a: { z: 1, a: 2 } }" }), 0, 8)
      assert.is_not_nil(outline)
      local entry = outline.entries[1]
      assert.equals("a", entry.sort_key)
      assert.is_not_nil(entry.child)
      assert.same({ "z", "a" }, keys_in_order(entry.child))
    end)
  end)

  describe("non-sortable structures", function()
    it("returns nil for an array literal", function()
      if not has_ruby then
        pending("ruby treesitter parser not available")
        return
      end
      assert.is_nil(build_at(make_buf({ "a = [1, 2, 3]" }), 0, 8))
    end)
  end)
end)
