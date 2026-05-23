-- Tests deliberately stay at the Outline-boundary contract; the internal
-- intermediate representation and capture interpretation are not pinned so
-- the builder can be refactored without touching this spec.

local ts = require("tests.support.treesitter")

describe("sort-keys.handlers.declarative.json_builder", function()
  local builder
  local has_json

  before_each(function()
    package.loaded["sort-keys.handlers.declarative.json_builder"] = nil
    builder = require("sort-keys.handlers.declarative.json_builder")
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

  local json_toml = {
    can_sort_object = true,
    can_sort_array = true,
    can_deep = true,
    key_quoting = "logical",
    comment_aware = false,
    comment_strategy = "none",
    default_separator_object = ",",
    default_separator_array = ",",
    mixed_key_types = false,
    query_file = "sort-keys.scm",
  }

  describe("build — cursor target on a JSON object", function()
    it("returns an Outline whose kind is 'object' with entry sort_keys matching the source", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '{ "c": 3, "a": 1, "b": 2 }' }, "json")
      local target = { kind = "cursor", pos = { 0, 4 } }
      local outline = builder.build(bufnr, target, {
        filetype = "json",
        query_text = json_query,
        toml = json_toml,
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
    end)

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
        toml = json_toml,
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
        toml = json_toml,
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
      local config = { filetype = "json", query_text = json_query, toml = json_toml }
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
        toml = json_toml,
      })
      assert.is_nil(outline)
    end)

    it("returns nil / error when .toml ↔ .scm capability disagree", function()
      if not has_json then
        pending("JSON treesitter parser not available")
        return
      end
      -- .scm declares kind="object" but .toml says can_sort_object = false.
      local clashing_toml = vim.tbl_deep_extend("force", {}, json_toml)
      clashing_toml.can_sort_object = false
      local bufnr = make_buf({ '{ "a": 1 }' }, "json")
      local target = { kind = "cursor", pos = { 0, 4 } }
      local outline = builder.build(bufnr, target, {
        filetype = "json",
        query_text = json_query,
        toml = clashing_toml,
      })
      assert.is_nil(outline)
    end)
  end)
end)
