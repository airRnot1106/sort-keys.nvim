-- Pins the Outline-boundary contract of kdl_builder. KDL has two container
-- shapes (document root + node_children block); both are object-like and each
-- entry is a `node` keyed by its name. These cases nail that contract plus the
-- comment_attach delegation and the deep-recursion child linkage.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.kdl.builder", function()
  local builder
  local has_kdl

  before_each(function()
    package.loaded["sort-keys.languages.kdl.builder"] = nil
    builder = require("sort-keys.languages.kdl.builder")
    has_kdl = ts.has_parser("kdl")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "kdl"
    return bufnr
  end

  local kdl_query = [[
((document) @sortkeys.container)
((node_children) @sortkeys.container)
((node) @sortkeys.entry)
[
  (single_line_comment)
  (multi_line_comment)
] @sortkeys.comment
]]

  local function options_for(overrides)
    local base = {
      can_sort_object = true,
      can_sort_array = false,
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
      filetype = "kdl",
      query_text = kdl_query,
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

  describe("document root (object-like)", function()
    it("returns kind='object' with sort_keys from the node names, all movable", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'b "2"', 'a "1"' })
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "a", "b" }, keys_of(outline))
      for _, e in ipairs(outline.entries) do
        assert.is_true(e.movable)
        assert.equals("pair", e.kind)
      end
    end)
  end)

  describe("node_children block (object-like)", function()
    it("returns kind='object' keyed by the child node names", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "config {", '  version "1"', '  name "demo"', "}" })
      local outline = build_at(bufnr, 1, 4)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "name", "version" }, keys_of(outline))
    end)

    it("strips the quotes of a quoted node name into the sort_key", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "config {", '  "b key" 2', '  "a key" 1', "}" })
      local outline = build_at(bufnr, 1, 4)
      assert.is_not_nil(outline)
      assert.same({ "a key", "b key" }, keys_of(outline))
    end)
  end)

  describe("deep recursion linkage", function()
    it("hangs a nested node_children off its owning node's entry.child", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "parent {", "  inner-b 2", "  inner-a 1", "}" })
      -- Cursor on the `parent` name (col 0, before the `{`) resolves to the
      -- document root, whose single entry is `parent`; that entry must carry
      -- the inner block as its child outline.
      local outline = build_at(bufnr, 0, 0)
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      local child = outline.entries[1].child
      assert.is_not_nil(child)
      assert.equals("object", child.kind)
      assert.same({ "inner-a", "inner-b" }, keys_of(child))
    end)
  end)

  describe("delegation to comment_attach", function()
    it("expands an entry's range to swallow its leading comment when comment_aware", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "// leading for a", "a 1" })
      local outline = build_at(bufnr, 1, 0, options_for({ comment_aware = true }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      -- Comment "// leading for a" starts at (row 0, col 0); after attach the
      -- entry range must start there, not at the node on row 1.
      assert.equals(0, outline.entries[1].range[1])
    end)

    it("leaves entry ranges anchored at the node when comment_aware is false", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "// leading for a", "a 1" })
      local outline = build_at(bufnr, 1, 0, options_for({ comment_aware = false }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      assert.equals(1, outline.entries[1].range[1])
    end)
  end)

  describe("return value arity contract", function()
    it("returns exactly one value (Outline | nil)", function()
      if not has_kdl then
        pending("kdl treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'a "1"', 'b "2"' })
      assert.equals(1, select("#", build_at(bufnr, 0, 0)))
    end)
  end)
end)
