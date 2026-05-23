-- Pins the Outline-boundary contract of yaml_builder. Like json_builder_spec
-- the goal is to lock the public shape (kind, structural_separator,
-- trailing_separator_allowed, entries' sort_key / movable / range) without
-- prescribing the internal traversal. Per-style separator and anchor-aware
-- movable are the YAML-specific contracts that earn their own cases.

local ts = require("tests.support.treesitter")

describe("sort-keys.handlers.declarative.yaml_builder", function()
  local builder
  local has_yaml

  before_each(function()
    package.loaded["sort-keys.handlers.declarative.yaml_builder"] = nil
    builder = require("sort-keys.handlers.declarative.yaml_builder")
    has_yaml = ts.has_parser("yaml")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "yaml"
    return bufnr
  end

  local yaml_query = [[
((block_mapping)  @sortkeys.container (#set! sortkeys.kind "object"))
((block_sequence) @sortkeys.container (#set! sortkeys.kind "array"))
((flow_mapping)   @sortkeys.container (#set! sortkeys.kind "object"))
((flow_sequence)  @sortkeys.container (#set! sortkeys.kind "array"))

((block_mapping_pair) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((flow_pair)          @sortkeys.entry (#set! sortkeys.entry_kind "pair"))

((block_sequence_item)               @sortkeys.entry (#set! sortkeys.entry_kind "element"))
((flow_sequence (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))

((comment) @sortkeys.comment)
]]

  local yaml_toml = {
    can_sort_object = true,
    can_sort_array = true,
    can_deep = true,
    key_quoting = "logical",
    comment_aware = true,
    mixed_key_types = false,
    query_file = "sort-keys.scm",
  }

  local function build_at(bufnr, row, col)
    return builder.build(bufnr, { kind = "cursor", pos = { row, col } }, {
      filetype = "yaml",
      query_text = yaml_query,
      toml = yaml_toml,
    })
  end

  describe("block_mapping", function()
    it("returns an Outline of kind='object' with no inline separator", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "b: 2", "a: 1" })
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      -- Block style uses newline-based separation; the gap text already
      -- carries the indentation/newline so the applier must NOT inject a
      -- separator. Empty string is the contract for that.
      assert.equals("", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)

      local keys = {}
      for _, e in ipairs(outline.entries) do
        keys[e.sort_key] = true
      end
      assert.is_true(keys["a"])
      assert.is_true(keys["b"])
    end)

    it("normalizes quoted keys via key_normalize.yaml", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '"b": 2', "'a': 1" })
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      local keys = {}
      for _, e in ipairs(outline.entries) do
        keys[e.sort_key] = true
      end
      assert.is_true(keys["a"]) -- single-quote stripped
      assert.is_true(keys["b"]) -- double-quote stripped
    end)
  end)

  describe("block_sequence", function()
    it("returns an Outline of kind='array' with no inline separator", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "- c", "- a", "- b" })
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.equals("", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
      assert.equals(3, #outline.entries)
    end)
  end)

  describe("flow_mapping", function()
    it("returns an Outline whose separator is ',' and forbids trailing comma", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      -- Wrap the flow mapping in a top-level pair so the buffer is valid
      -- YAML. The target cursor points into the flow_mapping itself.
      local bufnr = make_buf({ "root: { b: 2, a: 1 }" })
      local outline = build_at(bufnr, 0, 10)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals(",", outline.structural_separator)
      assert.is_false(outline.trailing_separator_allowed)
    end)
  end)

  describe("flow_sequence", function()
    it("returns an Outline whose separator is ',' and forbids trailing comma", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "root: [c, a, b]" })
      local outline = build_at(bufnr, 0, 10)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.equals(",", outline.structural_separator)
      assert.is_false(outline.trailing_separator_allowed)
      assert.equals(3, #outline.entries)
    end)
  end)

  describe("anchor / alias safety", function()
    -- Entries that carry an anchor definition or an alias reference must
    -- not be reordered past their counterparts, or the resulting YAML
    -- becomes a forward reference (which most parsers reject). Marking
    -- those entries movable=false defers the policy to the existing
    -- anchored-slot rule in core/policy.lua without inventing new state.

    local function entries_by_key(outline)
      local out = {}
      for _, e in ipairs(outline.entries) do
        out[e.sort_key] = e
      end
      return out
    end

    it("marks an entry containing an anchor (&name) as movable=false", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "a: &anchor 1", "b: 2" })
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      local by_key = entries_by_key(outline)
      assert.is_false(by_key["a"].movable)
      assert.is_true(by_key["b"].movable)
    end)

    it("marks an entry containing an alias (*name) as movable=false", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "a: &anchor 1", "b: *anchor", "c: 3" })
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      local by_key = entries_by_key(outline)
      assert.is_false(by_key["a"].movable) -- anchor
      assert.is_false(by_key["b"].movable) -- alias
      assert.is_true(by_key["c"].movable)
    end)
  end)

  describe("delegation to comment_attach", function()
    -- Same delegation contract as json_builder: when comment_aware is true,
    -- a leading line comment must expand the following entry's range so
    -- it travels with the entry on reorder.

    it(
      "expands an entry's range to swallow a leading comment when comment_aware is true",
      function()
        if not has_yaml then
          pending("yaml treesitter parser not available")
          return
        end
        -- A top-level comment in YAML is parented at the stream, not at the
        -- block_mapping; the builder must still assign it to the mapping it
        -- precedes. Cursor sits on the pair line so pick_innermost finds the
        -- mapping.
        local bufnr = make_buf({ "# leading for a", "a: 1" })
        local outline = build_at(bufnr, 1, 0)
        assert.is_not_nil(outline)
        assert.equals(1, #outline.entries)
        -- After attach the entry's range must start at the comment, not at
        -- the pair on row 1.
        assert.equals(0, outline.entries[1].range[1])
        assert.equals(0, outline.entries[1].range[2])
      end
    )

    it("leaves entry ranges untouched when comment_aware is false", function()
      if not has_yaml then
        pending("yaml treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "# leading for a", "a: 1" })
      local outline = builder.build(bufnr, { kind = "cursor", pos = { 1, 0 } }, {
        filetype = "yaml",
        query_text = yaml_query,
        toml = vim.tbl_deep_extend("force", {}, yaml_toml, { comment_aware = false }),
      })
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      -- Without delegation the entry range starts where the pair node
      -- starts (row 1, col 0).
      assert.equals(1, outline.entries[1].range[1])
      assert.equals(0, outline.entries[1].range[2])
    end)
  end)
end)
