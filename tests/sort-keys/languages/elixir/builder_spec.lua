-- Pins the Outline-boundary contract of elixir_builder.
--
-- Two container shapes share the AST scaffolding:
--   map  (`%{...}` / `%Struct{...}`) — atom-shorthand pairs and arrow
--        binary operators
--   list with a `keywords` child (a keyword list)
--
-- The spec asserts the inclusion side (map / struct / keyword list yield a
-- sortable Outline with normalized keys) and the exclusion side (a plain,
-- positional list is dropped before pick_innermost).

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.elixir.builder", function()
  local builder
  local has_elixir

  before_each(function()
    package.loaded["sort-keys.languages.elixir.builder"] = nil
    builder = require("sort-keys.languages.elixir.builder")
    has_elixir = ts.has_parser("elixir")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "elixir"
    return bufnr
  end

  local elixir_query = [[
((map) @sortkeys.container (#set! sortkeys.kind "object"))
((list (keywords)) @sortkeys.container (#set! sortkeys.kind "object"))

((pair
   key: (_) @sortkeys.key
   value: (_) @sortkeys.value) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((map_content
   (binary_operator
     left: (_) @sortkeys.key
     right: (_) @sortkeys.value) @sortkeys.entry)
 (#set! sortkeys.entry_kind "pair"))

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
      filetype = "elixir",
      query_text = elixir_query,
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

  describe("map (atom-shorthand keys)", function()
    it("returns kind='object' with the colon-stripped keys", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "%{banana: 2, apple: 1}" })
      local outline = build_at(bufnr, 0, 4)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "apple", "banana" }, sorted_keys(outline))
    end)

    it("uses the comma inter-entry separator with trailing allowed", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "%{a: 1, b: 2}" }), 0, 4)
      assert.is_not_nil(outline)
      assert.equals(",", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
    end)
  end)

  describe("map (arrow keys)", function()
    it("normalizes string and atom keys on `=>` entries", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ '%{"zed" => 1, :alpha => 2}' }), 0, 4)
      assert.is_not_nil(outline)
      assert.same({ "alpha", "zed" }, sorted_keys(outline))
    end)
  end)

  describe("keyword list", function()
    it("treats a `[k: v]` list as kind='object'", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "[c: 3, a: 1, b: 2]" }), 0, 2)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "a", "b", "c" }, sorted_keys(outline))
    end)
  end)

  describe("deep recursion", function()
    it("attaches a child Outline for a nested map value", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local outline = build_at(make_buf({ "%{outer: %{z: 1, a: 2}}" }), 0, 4)
      assert.is_not_nil(outline)
      local outer = outline.entries[1]
      assert.equals("outer", outer.sort_key)
      assert.is_not_nil(outer.child)
      assert.same({ "a", "z" }, sorted_keys(outer.child))
    end)
  end)

  describe("comment delegation", function()
    it("expands an entry range to swallow its leading comment when comment_aware", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "%{",
        "  # leading",
        "  b: 2,",
        "  a: 1",
        "}",
      })
      local outline = build_at(bufnr, 1, 0)
      assert.is_not_nil(outline)
      -- The `b` entry must start at the comment row (1, 0-indexed), proving
      -- comment_attach widened its range.
      local b_entry
      for _, e in ipairs(outline.entries) do
        if e.sort_key == "b" then
          b_entry = e
        end
      end
      assert.is_not_nil(b_entry)
      assert.equals(1, b_entry.range[1])
    end)
  end)

  describe("non-sortable structures", function()
    it("returns nil for a plain positional list", function()
      if not has_elixir then
        pending("elixir treesitter parser not available")
        return
      end
      assert.is_nil(build_at(make_buf({ "[1, 2, 3]" }), 0, 2))
    end)
  end)
end)
