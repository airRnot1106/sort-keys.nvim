-- Pins the Outline-boundary contract of python_builder. Python has three
-- sortable container shapes (`dictionary`, `list`, `set`); tuple is
-- intentionally excluded. Dict entries split into pair / dictionary_splat,
-- and the latter must be movable=false because spread order is significant.
-- List/set elements include `list_splat` (`*xs`), which is also pinned.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.python.builder", function()
  local builder
  local has_python

  before_each(function()
    package.loaded["sort-keys.languages.python.builder"] = nil
    builder = require("sort-keys.languages.python.builder")
    has_python = ts.has_parser("python")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "python"
    return bufnr
  end

  local python_query = [[
((dictionary) @sortkeys.container (#set! sortkeys.kind "object"))
((list)       @sortkeys.container (#set! sortkeys.kind "array"))
((set)        @sortkeys.container (#set! sortkeys.kind "array"))

((pair)             @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((dictionary_splat) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))

((list (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))
((set  (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))

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
      filetype = "python",
      query_text = python_query,
      options = t or options_for(),
    })
  end

  local function keys_in_source_order(outline)
    local out = {}
    for _, e in ipairs(outline.entries) do
      out[#out + 1] = e.sort_key
    end
    return out
  end

  local function sorted_keys(outline)
    local out = keys_in_source_order(outline)
    table.sort(out)
    return out
  end

  describe("dictionary (object-like)", function()
    it("returns kind='object' with sort_keys from each pair's key text", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'd = {"b": 2, "a": 1}' })
      local outline = build_at(bufnr, 0, 5)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.same({ "a", "b" }, sorted_keys(outline))
      for _, e in ipairs(outline.entries) do
        assert.equals("pair", e.kind)
      end
    end)

    it("classifies a `**spread` entry as movable=false (semantically pinned)", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      -- `{**defaults, "a": 1}` is NOT equivalent to `{"a": 1, **defaults}`,
      -- so the splat must keep its source position regardless of sort.
      local bufnr = make_buf({ 'd = {**defaults, "a": 1, "b": 2}' })
      local outline = build_at(bufnr, 0, 5)
      assert.is_not_nil(outline)
      local pinned = 0
      for _, e in ipairs(outline.entries) do
        if not e.movable then
          pinned = pinned + 1
        end
      end
      assert.equals(1, pinned)
    end)

    it("normalizes a string key (strips quotes, decodes escapes)", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'd = {"b\\nx": 1, "a": 2}' })
      local outline = build_at(bufnr, 0, 5)
      assert.is_not_nil(outline)
      -- "b\nx" decoded contains a real LF, which sorts > "a".
      assert.same({ "a", "b\nx" }, sorted_keys(outline))
    end)

    it("takes an integer / float / bool / None key as its surface text", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'd = {42: "x", None: "y", True: "z", 3.14: "w"}' })
      local outline = build_at(bufnr, 0, 5)
      assert.is_not_nil(outline)
      assert.same({ "3.14", "42", "None", "True" }, sorted_keys(outline))
    end)

    it("pins a pair whose key is an expression (attribute / call) movable=false", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      -- A call expression as a key is a runtime value; reordering past
      -- another pair could change semantics if the call has side effects.
      local bufnr = make_buf({ 'd = {func(): 1, "a": 2}' })
      local outline = build_at(bufnr, 0, 5)
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

  describe("list (array-like)", function()
    it("returns kind='array' with sort_keys from each element's surface text", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "xs = [3, 1, 2]" })
      local outline = build_at(bufnr, 0, 7)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.same({ "1", "2", "3" }, sorted_keys(outline))
    end)

    it("classifies a `*splat` element as movable=false", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "xs = [*rest, 1, 2]" })
      local outline = build_at(bufnr, 0, 7)
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

  describe("set (array-like)", function()
    it("returns kind='array' with sort_keys from each element's surface text", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "s = {3, 1, 2}" })
      local outline = build_at(bufnr, 0, 6)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.same({ "1", "2", "3" }, sorted_keys(outline))
    end)
  end)

  describe("deep recursion linkage", function()
    it("hangs a nested dictionary value off its pair entry's child outline", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'd = {"outer": {"b": 2, "a": 1}}' })
      local outline = build_at(bufnr, 0, 5)
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      local child = outline.entries[1].child
      assert.is_not_nil(child)
      assert.equals("object", child.kind)
      assert.same({ "a", "b" }, sorted_keys(child))
    end)

    it("hangs a nested list value off its pair entry's child outline", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'd = {"xs": [3, 1, 2]}' })
      local outline = build_at(bufnr, 0, 5)
      assert.is_not_nil(outline)
      local child = outline.entries[1].child
      assert.is_not_nil(child)
      assert.equals("array", child.kind)
    end)
  end)

  describe("delegation to comment_attach", function()
    it("expands an entry's range to swallow its leading comment when comment_aware", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "d = {",
        "    # leading for a",
        '    "a": 1,',
        "}",
      })
      local outline = build_at(bufnr, 0, 4, options_for({ comment_aware = true }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      -- The leading comment is on row 1; after attach, the entry's range must
      -- start at row 1, not row 2 (the actual pair row).
      assert.equals(1, outline.entries[1].range[1])
    end)

    it("leaves entry ranges anchored at the pair when comment_aware is false", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "d = {",
        "    # leading for a",
        '    "a": 1,',
        "}",
      })
      local outline = build_at(bufnr, 0, 4, options_for({ comment_aware = false }))
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      assert.equals(2, outline.entries[1].range[1])
    end)
  end)

  describe("return value arity contract", function()
    it("returns exactly one value (Outline | nil)", function()
      if not has_python then
        pending("python treesitter parser not available")
        return
      end
      local bufnr = make_buf({ 'd = {"a": 1}' })
      assert.equals(1, select("#", build_at(bufnr, 0, 5)))
    end)
  end)
end)
