-- Pins the Outline-boundary contract of toml_builder. TOML has multiple
-- container shapes (inline_table / array / [section] / [[array_of_tables]]
-- / root-level pair group) with different separator policies, so these
-- specs cover each shape's structural_separator + trailing flag, the
-- dynamic dotted-key sort_key, and the root-pseudo-container synthesis.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.toml.builder", function()
  local builder
  local has_toml

  before_each(function()
    package.loaded["sort-keys.languages.toml.builder"] = nil
    builder = require("sort-keys.languages.toml.builder")
    has_toml = ts.has_parser("toml")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "toml"
    return bufnr
  end

  local toml_query = [[
((inline_table) @sortkeys.container
  (#set! sortkeys.kind "object"))

((table) @sortkeys.container
  (#set! sortkeys.kind "object"))

((table_array_element) @sortkeys.container
  (#set! sortkeys.kind "object"))

((array) @sortkeys.container
  (#set! sortkeys.kind "array"))

((pair) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

(array
  (_) @sortkeys.entry
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
      query_file = "sort-keys.scm",
    }
    for k, v in pairs(overrides or {}) do
      base[k] = v
    end
    return base
  end

  local function build_at(bufnr, row, col, t)
    return builder.build(bufnr, { kind = "cursor", pos = { row, col } }, {
      filetype = "toml",
      query_text = toml_query,
      options = t or options_for(),
    })
  end

  local function keys_in_order(outline)
    local out = {}
    for _, e in ipairs(outline.entries) do
      out[#out + 1] = e.sort_key
    end
    return out
  end

  describe("inline_table", function()
    it("returns kind='object' with bare keys and `,` as separator", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "x = { b = 2, a = 1 }" })
      local outline = build_at(bufnr, 0, 6)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals(",", outline.structural_separator)
      -- TOML 1.0 forbids a trailing comma inside inline_table.
      assert.is_false(outline.trailing_separator_allowed)
      local keys = keys_in_order(outline)
      assert.equals(2, #keys)
      table.sort(keys)
      assert.same({ "a", "b" }, keys)
    end)
  end)

  describe("array (inline)", function()
    it("returns kind='array' with element entries and `,` + trailing allowed", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'x = ["b", "a", "c"]' })
      local outline = build_at(bufnr, 0, 5)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.equals(",", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
      assert.equals(3, #outline.entries)
    end)
  end)

  describe("[section] table", function()
    it("returns kind='object' with newline-style separator and pair entries", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "[package]",
        'name = "demo"',
        'version = "1.0"',
        'authors = ["a"]',
      })
      local outline = build_at(bufnr, 1, 0)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      -- Standard tables use the buffer gap (newline) as their separator;
      -- emitting `,` would corrupt the file.
      assert.equals("", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
      assert.equals(3, #outline.entries)
    end)
  end)

  describe("[[array_of_tables]] element", function()
    it("treats each [[bin]] block as its own object container", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "[[bin]]",
        'name = "main"',
        'path = "src/main.rs"',
        "",
        "[[bin]]",
        'name = "helper"',
        'path = "src/bin/helper.rs"',
      })
      -- Cursor inside the first [[bin]] block.
      local outline = build_at(bufnr, 1, 0)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals("", outline.structural_separator)
      assert.equals(2, #outline.entries)
      local keys = keys_in_order(outline)
      table.sort(keys)
      assert.same({ "name", "path" }, keys)
    end)
  end)

  describe("root-level pseudo container", function()
    it("synthesizes a container covering all document-direct pairs when ≥2 exist", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        'title = "x"',
        "version = 2",
        "",
        "[package]",
        'name = "demo"',
      })
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals("", outline.structural_separator)
      assert.equals(2, #outline.entries)
      local keys = keys_in_order(outline)
      table.sort(keys)
      assert.same({ "title", "version" }, keys)
    end)

    it("does NOT synthesize a pseudo container when only one root pair exists", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        'title = "only"',
        "",
        "[package]",
        'name = "demo"',
      })
      -- Cursor on the lone root pair; with no pseudo container synthesized
      -- and no other container starting on that row, the builder reports
      -- "nothing to sort here".
      local outline = build_at(bufnr, 0, 0)
      assert.is_nil(outline)
    end)
  end)

  describe("dotted key", function()
    it('uses the full dotted text "a.b.c" as the flat sort_key', function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "[s]",
        'a.b.c = "v"',
        'z = "w"',
      })
      local outline = build_at(bufnr, 1, 0)
      assert.is_not_nil(outline)
      local found_dotted = false
      for _, e in ipairs(outline.entries) do
        if e.sort_key == "a.b.c" then
          found_dotted = true
          assert.is_true(e.movable)
        end
      end
      assert.is_true(found_dotted)
    end)
  end)

  describe("delegation to comment_attach", function()
    it(
      "expands an entry's range to swallow a leading `# comment` when comment_aware is true",
      function()
        if not has_toml then
          pending("toml treesitter parser not available")
          return
        end
        local bufnr = make_buf({
          "[s]",
          "# leading for b",
          'b = "2"',
          'a = "1"',
        })
        local outline = build_at(bufnr, 1, 0)
        assert.is_not_nil(outline)
        local by = {}
        for _, e in ipairs(outline.entries) do
          by[e.sort_key] = e
        end
        local b_entry = by["b"]
        assert.is_not_nil(b_entry)
        -- Range row should now start at the comment line (row 1) rather than
        -- the `b = "2"` line (row 2).
        assert.equals(1, b_entry.range[1])
      end
    )

    it("leaves entry ranges untouched when comment_aware is false", function()
      if not has_toml then
        pending("toml treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "[s]",
        "# leading for b",
        'b = "2"',
        'a = "1"',
      })
      local outline = build_at(bufnr, 1, 0, options_for({ comment_aware = false }))
      assert.is_not_nil(outline)
      local by = {}
      for _, e in ipairs(outline.entries) do
        by[e.sort_key] = e
      end
      assert.equals(2, by["b"].range[1])
    end)
  end)
end)
