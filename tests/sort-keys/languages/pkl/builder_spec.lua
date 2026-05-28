-- Pins the Outline-boundary contract of pkl_builder. Pkl has two container
-- shapes (module root + objectBody) and the object-vs-array distinction is
-- voted on from entry shapes: classProperty / objectProperty / objectEntry are
-- keyed (object), objectElement is positional (array). These cases nail that
-- contract plus the comment_attach delegation.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.pkl.builder", function()
  local builder
  local has_pkl

  before_each(function()
    package.loaded["sort-keys.languages.pkl.builder"] = nil
    builder = require("sort-keys.languages.pkl.builder")
    has_pkl = ts.has_parser("pkl")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "pkl"
    return bufnr
  end

  local pkl_query = [[
((module) @sortkeys.container)
((objectBody) @sortkeys.container)
((classProperty) @sortkeys.entry)
((objectProperty) @sortkeys.entry)
((objectEntry) @sortkeys.entry)
((objectElement) @sortkeys.entry)
((lineComment) @sortkeys.comment)
((blockComment) @sortkeys.comment)
((docComment) @sortkeys.comment)
]]

  local function options_for(overrides)
    local base = {
      can_sort_object = true,
      can_sort_array = true,
      can_deep = true,
      key_quoting = "logical",
      comment_aware = true,
      mixed_key_types = true,
      structural_separator = "",
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
      filetype = "pkl",
      query_text = pkl_query,
      options = t or options_for(),
    })
  end

  local function keys_of(outline)
    local out = {}
    for _, e in ipairs(outline.entries) do
      out[#out + 1] = e.sort_key
    end
    table.sort(out)
    return out
  end

  describe("module root (object-like)", function()
    it("returns kind='object' with sort_keys from the property identifiers", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "b = 2", "a = 1" })
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "a", "b" }, keys_of(outline))
      for _, e in ipairs(outline.entries) do
        assert.is_true(e.movable)
      end
    end)
  end)

  describe("object body voted object-like", function()
    it("returns kind='object' for a body of objectProperty entries", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "bird {", "  b = 2", "  a = 1", "}" })
      local outline = build_at(bufnr, 1, 4)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "a", "b" }, keys_of(outline))
    end)

    it("strips the brackets/quotes of a mapping key into the sort_key", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "m = new Mapping {", '  ["b"] = 2', '  ["a"] = 1', "}" })
      local outline = build_at(bufnr, 1, 4)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "a", "b" }, keys_of(outline))
    end)
  end)

  describe("object body voted array-like", function()
    it("returns kind='array' for a listing of bare elements, all movable", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "l = new Listing {", '  "c"', '  "a"', "}" })
      local outline = build_at(bufnr, 1, 4)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      for _, e in ipairs(outline.entries) do
        assert.equals("element", e.kind)
        assert.is_true(e.movable)
      end
    end)
  end)

  describe("delegation to comment_attach", function()
    it("expands an entry's range to swallow its leading comment when comment_aware", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "// leading for a", "a = 1" })
      local outline = build_at(bufnr, 1, 0, options_for({ comment_aware = true }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      -- Comment "// leading for a" starts at (row 0, col 0); after attach the
      -- entry range must start there, not at the property on row 1.
      assert.equals(0, outline.entries[1].range[1])
    end)

    it("leaves entry ranges anchored at the property when comment_aware is false", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "// leading for a", "a = 1" })
      local outline = build_at(bufnr, 1, 0, options_for({ comment_aware = false }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      assert.equals(1, outline.entries[1].range[1])
    end)
  end)

  describe("return value arity contract", function()
    it("returns exactly one value (Outline | nil)", function()
      if not has_pkl then
        pending("pkl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "a = 1", "b = 2" })
      assert.equals(1, select("#", build_at(bufnr, 0, 0)))
    end)
  end)
end)
