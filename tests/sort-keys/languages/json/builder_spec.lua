-- Tests deliberately stay at the Outline-boundary contract; the internal
-- intermediate representation and capture interpretation are not pinned so
-- the builder can be refactored without touching this spec.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.json.builder", function()
  local builder
  local has_json

  before_each(function()
    package.loaded["sort-keys.languages.json.builder"] = nil
    builder = require("sort-keys.languages.json.builder")
    has_json = ts.has_parser("json")
  end)

  local function make_buf(lines, ft)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = ft
    return bufnr
  end

  local json_query = [[
((object) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

((pair
   key:   (string (string_content) @sortkeys.key)
   value: (_)                       @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((array
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))
]]

  local json_options = {
    can_sort_object = true,
    can_sort_array = true,
    can_deep = true,
    key_quoting = "logical",
    comment_aware = false,
    mixed_key_types = false,
    query_file = "sort-keys.scm",
  }

  describe("build — cursor target on a JSON object", function()
    it(
      "returns an Outline whose kind is 'object' with entry sort_keys matching the source",
      function()
        if not has_json then
          pending("JSON treesitter parser not available")
          return
        end
        local bufnr = make_buf({ '{ "c": 3, "a": 1, "b": 2 }' }, "json")
        local target = { kind = "cursor", pos = { 0, 4 } }
        local outline = builder.build(bufnr, target, {
          filetype = "json",
          query_text = json_query,
          options = json_options,
        })
        assert.is_not_nil(outline)
        assert.equals("object", outline.kind)

        local got = {}
        for _, e in ipairs(outline.entries) do
          got[e.sort_key] = true
        end
        assert.is_true(got["a"])
        assert.is_true(got["b"])
        assert.is_true(got["c"])
      end
    )

    it("marks every entry movable=true under a cursor target", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '{ "c": 3, "a": 1 }' }, "json")
      local target = { kind = "cursor", pos = { 0, 4 } }
      local outline = builder.build(bufnr, target, {
        filetype = "json",
        query_text = json_query,
        options = json_options,
      })
      assert.is_not_nil(outline)
      for _, e in ipairs(outline.entries) do
        assert.is_true(e.movable)
      end
    end)
  end)

  describe("build — array target", function()
    it("returns an Outline whose kind is 'array' for an array container", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '[ "c", "a", "b" ]' }, "json")
      local target = { kind = "cursor", pos = { 0, 4 } }
      local outline = builder.build(bufnr, target, {
        filetype = "json",
        query_text = json_query,
        options = json_options,
      })
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.equals(3, #outline.entries)
    end)
  end)

  -- Lua silently drops extra return values on `local x = f()`, so without
  -- `select("#", ...)` a future drift toward Go/Rust-style `(value, err)`
  -- would pass every other test. This pins the single-return arity.
  describe("build — return value arity contract", function()
    it("returns exactly one value (Outline | nil)", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '{ "a": 1 }' }, "json")
      local target = { kind = "cursor", pos = { 0, 4 } }
      local config = { filetype = "json", query_text = json_query, options = json_options }
      assert.equals(1, select("#", builder.build(bufnr, target, config)))
    end)
  end)

  describe("error conditions return nil", function()
    it("returns nil when target has no sortable container", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '"just a string"' }, "json")
      local target = { kind = "cursor", pos = { 0, 4 } }
      local outline = builder.build(bufnr, target, {
        filetype = "json",
        query_text = json_query,
        options = json_options,
      })
      assert.is_nil(outline)
    end)

    it("returns nil / error when .toml ↔ .scm capability disagree", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      -- .scm declares kind="object" but .toml says can_sort_object = false.
      local clashing_options = vim.tbl_deep_extend("force", {}, json_options)
      clashing_options.can_sort_object = false
      local bufnr = make_buf({ '{ "a": 1 }' }, "json")
      local target = { kind = "cursor", pos = { 0, 4 } }
      local outline = builder.build(bufnr, target, {
        filetype = "json",
        query_text = json_query,
        options = clashing_options,
      })
      assert.is_nil(outline)
    end)
  end)

  describe("delegation to comment_attach", function()
    -- The detail layer's job is to feed entries + (comment) nodes to the
    -- pure policy module. We pin the wiring by inspecting the observable
    -- consequence: when comment_aware is true, an entry's range should
    -- expand to swallow its leading comment; when false, the range must
    -- stay anchored at the pair node.

    local jsonc_query = json_query .. "\n((comment) @sortkeys.comment)\n"

    local function make_jsonc_buf()
      return make_buf({
        "{",
        "  // leading for a",
        '  "a": 1',
        "}",
      }, "json")
    end

    it(
      "expands an entry's range to swallow a leading comment when comment_aware is true",
      function()
        if not has_json then
          pending("JSON treesitter parser not available")
          return
        end
        local aware_options = vim.tbl_deep_extend(
          "force",
          {},
          json_options,
          { comment_aware = true }
        )
        local outline = builder.build(make_jsonc_buf(), { kind = "cursor", pos = { 0, 0 } }, {
          filetype = "json",
          query_text = jsonc_query,
          options = aware_options,
        })
        assert.is_not_nil(outline)
        assert.equals(1, #outline.entries)
        -- Comment "// leading for a" starts at (row 1, col 2); after attach
        -- the entry's range must start there, not at the pair on row 2.
        assert.equals(1, outline.entries[1].range[1])
        assert.equals(2, outline.entries[1].range[2])
      end
    )

    it("leaves entry ranges untouched when comment_aware is false", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      -- json_options.comment_aware is false (the JSON default).
      local outline = builder.build(make_jsonc_buf(), { kind = "cursor", pos = { 0, 0 } }, {
        filetype = "json",
        query_text = jsonc_query,
        options = json_options,
      })
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      -- Pair node "a" begins at (row 2, col 2); the range must NOT have
      -- absorbed the leading comment on row 1.
      assert.equals(2, outline.entries[1].range[1])
      assert.equals(2, outline.entries[1].range[2])
    end)

    -- Regression: the array entry query is `(array (_) @sortkeys.entry)`. The
    -- wildcard `(_)` matches every named child of the array, including
    -- `comment` nodes. Without a filter, the builder fed each trailing line
    -- comment into the sort pipeline as if it were a data element, which
    -- both garbled the result and crashed the applier when comment_attach
    -- expanded a real entry's range past the next "entry" (the comment).
    it("filters comment-captured nodes out of array entries when comment_aware is true", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local aware_options = vim.tbl_deep_extend("force", {}, json_options, { comment_aware = true })
      local bufnr = make_buf({
        "[",
        '  "c", // T-c',
        '  "a", // T-a',
        '  "b"',
        "]",
      }, "json")
      local outline = builder.build(bufnr, { kind = "cursor", pos = { 0, 0 } }, {
        filetype = "json",
        query_text = jsonc_query,
        options = aware_options,
      })
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      -- Three string elements; the two `// T-*` comments must NOT show up
      -- as entries even though `(_) @sortkeys.entry` matched them.
      assert.equals(3, #outline.entries)
      local keys = {}
      for _, e in ipairs(outline.entries) do
        keys[#keys + 1] = e.sort_key
      end
      table.sort(keys)
      assert.same({ '"a"', '"b"', '"c"' }, keys)
    end)
  end)
end)
