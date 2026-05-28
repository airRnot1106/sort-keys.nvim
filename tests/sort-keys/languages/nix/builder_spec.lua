-- Pins the Outline-boundary contract of nix_builder. Nix has six container
-- shapes with three separator policies and two AST quirks (binding_set
-- intermediate node, inherit-as-pinned-with-child). These specs cover
-- every container's separator/trailing flag, the entry classification per
-- shape, dotted/quoted attrpath normalization, and the inherit pin + inner
-- sort contract.

local ts = require("tests.support.treesitter")

describe("sort-keys.languages.nix.builder", function()
  local builder
  local has_nix

  before_each(function()
    package.loaded["sort-keys.languages.nix.builder"] = nil
    builder = require("sort-keys.languages.nix.builder")
    has_nix = ts.has_parser("nix")
  end)

  local function make_buf(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "nix"
    return bufnr
  end

  local nix_query = [[
((attrset_expression) @sortkeys.container
  (#set! sortkeys.kind "object"))

((rec_attrset_expression) @sortkeys.container
  (#set! sortkeys.kind "object"))

((let_expression) @sortkeys.container
  (#set! sortkeys.kind "object"))

((list_expression) @sortkeys.container
  (#set! sortkeys.kind "array"))

((formals) @sortkeys.container
  (#set! sortkeys.kind "object"))

((inherit) @sortkeys.container
  (#set! sortkeys.kind "array"))

((inherit_from) @sortkeys.container
  (#set! sortkeys.kind "array"))

((binding) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

((inherit) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

((inherit_from) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

(list_expression
  (_) @sortkeys.entry
  (#set! sortkeys.entry_kind "element"))

((formal) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

((ellipses) @sortkeys.entry
  (#set! sortkeys.entry_kind "element"))

(inherited_attrs
  (identifier) @sortkeys.entry
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
      filetype = "nix",
      query_text = nix_query,
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

  describe("attrset", function()
    it("returns kind='object' with ';' separator and trailing allowed", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "{ b = 2; a = 1; }" })
      local outline = build_at(bufnr, 0, 2)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals(";", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
      local keys = keys_in_order(outline)
      table.sort(keys)
      assert.same({ "a", "b" }, keys)
    end)
  end)

  describe("rec_attrset", function()
    it("sorts even though entries may reference each other (Nix is lazy)", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "rec { a = 1; b = a + 1; }" })
      local outline = build_at(bufnr, 0, 6)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals(";", outline.structural_separator)
      assert.equals(2, #outline.entries)
    end)
  end)

  describe("let_expression", function()
    it("treats let bindings as a sortable container with ';' separator", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "let b = 2; a = 1; in a + b" })
      local outline = build_at(bufnr, 0, 4)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals(";", outline.structural_separator)
      local keys = keys_in_order(outline)
      table.sort(keys)
      assert.same({ "a", "b" }, keys)
    end)
  end)

  describe("list_expression", function()
    it("returns kind='array' with whitespace-style empty separator", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = make_buf({ "x = [ c b a ]; " })
      local outline = build_at(bufnr, 0, 6)
      assert.is_not_nil(outline)
      assert.equals("array", outline.kind)
      assert.equals("", outline.structural_separator)
      assert.is_true(outline.trailing_separator_allowed)
      assert.equals(3, #outline.entries)
    end)
  end)

  describe("formals", function()
    it("returns kind='object' with ',' separator, trailing forbidden, and `...` pinned", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      -- A bare `f = ...;` binding outside an attrset is not valid Nix; wrap
      -- in `{ ... }` so the formals node parses cleanly.
      local bufnr = make_buf({ "{ f = { c, a, b ? 1, ... }: a + c; }" })
      -- Cursor inside the formals braces (column 8 = `c` formal).
      local outline = build_at(bufnr, 0, 8)
      assert.is_not_nil(outline)
      assert.equals("object", outline.kind)
      assert.equals(",", outline.structural_separator)
      assert.is_false(outline.trailing_separator_allowed)
      local has_ellipses = false
      local movable_count = 0
      for _, e in ipairs(outline.entries) do
        if e.sort_key == "..." then
          has_ellipses = true
          assert.is_false(e.movable)
        elseif e.movable then
          movable_count = movable_count + 1
        end
      end
      assert.is_true(has_ellipses)
      assert.equals(3, movable_count) -- a, b, c
    end)
  end)

  describe("inherit (no source)", function()
    it(
      "pins the inherit binding itself and exposes the identifier list as a child container",
      function()
        if not has_nix then
          pending("nix treesitter parser not available")
          return
        end
        -- Cursor on the second binding (extra) so the outer attrset is
        -- chosen, not the inner inherit container. The inner-container
        -- behavior is pinned by nix_e2e_spec.
        local bufnr = make_buf({ "{ inherit c a b; extra = 1; }" })
        local outline = build_at(bufnr, 0, 17)
        assert.is_not_nil(outline)
        local inherit_entry
        for _, e in ipairs(outline.entries) do
          if e.sort_key == "c" then
            inherit_entry = e
          end
        end
        assert.is_not_nil(inherit_entry)
        assert.is_false(inherit_entry.movable)
        assert.is_not_nil(inherit_entry.child)
        assert.equals("array", inherit_entry.child.kind)
        assert.equals("", inherit_entry.child.structural_separator)
        assert.equals(3, #inherit_entry.child.entries)
      end
    )
  end)

  describe("inherit_from (with source)", function()
    it("pins `inherit (e) ...;` and exposes inherited_attrs as a sortable child", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      -- Cursor right after `{` so the outer attrset wins over the inner
      -- inherit_from container (cursor outside the inherit_from span).
      local bufnr = make_buf({ "{ inherit (pkgs) lib stdenv; }" })
      local outline = build_at(bufnr, 0, 1)
      assert.is_not_nil(outline)
      assert.equals(1, #outline.entries)
      local e = outline.entries[1]
      assert.is_false(e.movable)
      assert.is_not_nil(e.child)
      assert.equals(2, #e.child.entries)
    end)
  end)

  describe("dotted attrpath", function()
    it('uses the full dotted text "a.b.c" as the flat sort_key', function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '{ a.b.c = "v"; z = "w"; }' })
      local outline = build_at(bufnr, 0, 2)
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

  describe("quoted attrpath", function()
    it("strips the surrounding quotes and uses the inner string as the sort_key", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '{ "foo.bar" = 1; z = 2; }' })
      local outline = build_at(bufnr, 0, 2)
      assert.is_not_nil(outline)
      local keys = keys_in_order(outline)
      table.sort(keys)
      assert.same({ "foo.bar", "z" }, keys)
    end)
  end)

  describe("delegation to comment_attach", function()
    it(
      "expands an entry's range to swallow a leading `# comment` when comment_aware is true",
      function()
        if not has_nix then
          pending("nix treesitter parser not available")
          return
        end
        local bufnr = make_buf({
          "{",
          "  # leading for b",
          "  b = 2;",
          "  a = 1;",
          "}",
        })
        local outline = build_at(bufnr, 0, 0)
        assert.is_not_nil(outline)
        local by = {}
        for _, e in ipairs(outline.entries) do
          by[e.sort_key] = e
        end
        assert.is_not_nil(by["b"])
        assert.equals(1, by["b"].range[1])
      end
    )

    it("leaves entry ranges untouched when comment_aware is false", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = make_buf({
        "{",
        "  # leading for b",
        "  b = 2;",
        "  a = 1;",
        "}",
      })
      local outline = build_at(bufnr, 0, 0, options_for({ comment_aware = false }))
      assert.is_not_nil(outline)
      local by = {}
      for _, e in ipairs(outline.entries) do
        by[e.sort_key] = e
      end
      assert.equals(2, by["b"].range[1])
    end)
  end)
end)
