-- builder_helpers is the shared treesitter-aware scaffolding used by every
-- language builder. The spec pins:
--   * pure helpers (node_range, node_id_key, pos_inside, contains_range,
--     range_area, normalize_element_text, validate_options) — exercised
--     with plain Lua fixtures.
--   * pick_innermost — exercised with stub containers; the cursor branch is
--     covered by container_pick_spec, so here we focus on the selection
--     branch's O(n) min-pass semantics.
--   * collect_matches — smoke-checked against a real JSON parser to confirm
--     the iter_matches triage + wildcard-dedup contract end-to-end.

local ts = require("tests.support.treesitter")

describe("sort-keys.core.builder_helpers", function()
  local h

  before_each(function()
    package.loaded["sort-keys.core.builder_helpers"] = nil
    h = require("sort-keys.core.builder_helpers")
  end)

  describe("pos_inside / contains_range / range_area", function()
    it("treats a position on the start corner as inside", function()
      assert.is_true(h.pos_inside({ 1, 5, 3, 9 }, 1, 5))
    end)

    it("treats a position on the end corner as inside (inclusive)", function()
      assert.is_true(h.pos_inside({ 1, 5, 3, 9 }, 3, 9))
    end)

    it("rejects a column before the start on the start row", function()
      assert.is_false(h.pos_inside({ 1, 5, 3, 9 }, 1, 4))
    end)

    it("rejects a column past the end on the end row", function()
      assert.is_false(h.pos_inside({ 1, 5, 3, 9 }, 3, 10))
    end)

    it("contains_range is true iff both endpoints of inner sit inside outer", function()
      assert.is_true(h.contains_range({ 0, 0, 5, 0 }, { 1, 2, 3, 4 }))
      assert.is_false(h.contains_range({ 0, 0, 2, 0 }, { 1, 2, 3, 4 }))
    end)

    it("range_area treats row span as dominant over column span", function()
      -- A two-row range is always larger than any single-row range, no
      -- matter how wide that single-row range is.
      assert.is_true(h.range_area({ 0, 0, 2, 0 }) > h.range_area({ 0, 0, 0, 999 }))
    end)
  end)

  describe("pick_innermost (selection branch)", function()
    local function container(range)
      return { range = range, node = {}, node_key = tostring(range[1]) }
    end

    it("returns the smallest container that fully covers the selection", function()
      local outer = container({ 0, 0, 10, 0 })
      local middle = container({ 1, 0, 8, 0 })
      local inner = container({ 2, 0, 5, 0 })
      local chosen = h.pick_innermost(
        { outer, middle, inner },
        { kind = "selection", range = { 3, 0, 4, 0 } }
      )
      assert.equals(inner, chosen)
    end)

    it("returns nil when no container covers the selection", function()
      local c = container({ 5, 0, 10, 0 })
      local chosen = h.pick_innermost({ c }, { kind = "selection", range = { 0, 0, 1, 0 } })
      assert.is_nil(chosen)
    end)

    it("breaks ties by first-occurrence (linear pass keeps earliest min)", function()
      -- The linear-pass semantics: if two containers have equal area, the
      -- first one encountered wins. Builders ingest containers in source
      -- position order, so this is "the lexicographically-first equal-size
      -- match" — useful determinism vs. the old sort-based version.
      local first = container({ 0, 0, 5, 0 })
      local second = container({ 0, 0, 5, 0 })
      local chosen = h.pick_innermost(
        { first, second },
        { kind = "selection", range = { 1, 0, 2, 0 } }
      )
      assert.equals(first, chosen)
    end)

    it("delegates cursor targets to container_pick.for_cursor", function()
      -- The cursor branch hands off to core/container_pick, whose 3-tier
      -- rule (strict containment -> same-row leftmost -> row-span innermost)
      -- has its own spec. We only pin that the delegation passes the cursor
      -- position through and routes containers in source order so the same
      -- result a builder would have got pre-extraction is preserved.
      local outer = container({ 0, 0, 10, 0 })
      local inner = container({ 2, 0, 5, 0 })
      local chosen = h.pick_innermost({ outer, inner }, { kind = "cursor", pos = { 3, 4 } })
      assert.equals(inner, chosen)
    end)
  end)

  describe("normalize_element_text", function()
    it("trims surrounding whitespace", function()
      assert.equals("foo", h.normalize_element_text("  foo  "))
    end)

    it("collapses runs of internal whitespace to a single space", function()
      assert.equals("a b c", h.normalize_element_text("a   b\t\nc"))
    end)

    it("leaves a string with no whitespace untouched", function()
      assert.equals("foo", h.normalize_element_text("foo"))
    end)
  end)

  describe("validate_options", function()
    it("returns true when every baseline capability flag is present", function()
      assert.is_true(h.validate_options({
        can_sort_object = true,
        can_sort_array = true,
        can_deep = true,
        key_quoting = "logical",
      }))
    end)

    it("returns false when any baseline flag is missing", function()
      assert.is_false(h.validate_options({
        can_sort_object = true,
        can_sort_array = true,
        can_deep = true,
        -- key_quoting omitted
      }))
    end)
  end)

  describe("ranges_intersect", function()
    it("returns true when two ranges share any column", function()
      assert.is_true(h.ranges_intersect({ 0, 0, 1, 5 }, { 1, 2, 2, 0 }))
    end)

    it("returns false for column-adjacent ranges on the same row", function()
      -- Half-open semantics: end column of r1 == start column of r2 means
      -- they touch, not overlap. Required by apply_selection_overlay so
      -- neighbouring entries don't both get flagged "selected" by a single
      -- character selection on their shared boundary.
      assert.is_false(h.ranges_intersect({ 0, 0, 0, 5 }, { 0, 5, 0, 10 }))
    end)

    it("returns false for disjoint ranges across rows", function()
      assert.is_false(h.ranges_intersect({ 0, 0, 1, 0 }, { 2, 0, 3, 0 }))
    end)
  end)

  describe("first_child_of_type", function()
    -- The treesitter integration is exercised by per-language builder
    -- specs; here we use a duck-typed stub so the spec stays pure-Lua and
    -- pins the iteration contract directly.
    local function stub(children)
      local node = { _children = children }
      function node:iter_children()
        local i = 0
        return function()
          i = i + 1
          local c = self._children[i]
          if c then
            return c
          end
        end
      end
      return node
    end
    local function child(type_name)
      return {
        _type = type_name,
        type = function(self)
          return self._type
        end,
      }
    end

    it("returns the first child whose type matches", function()
      local a, b1, b2 = child("a"), child("b"), child("b")
      local node = stub({ a, b1, b2 })
      assert.equals(b1, h.first_child_of_type(node, "b"))
    end)

    it("returns nil when no child matches", function()
      assert.is_nil(h.first_child_of_type(stub({ child("a") }), "b"))
    end)
  end)

  describe("capability_allows", function()
    it("permits object containers when can_sort_object is true", function()
      assert.is_true(h.capability_allows("object", { can_sort_object = true }))
      assert.is_false(h.capability_allows("object", { can_sort_object = false }))
    end)

    it("permits array containers when can_sort_array is true", function()
      assert.is_true(h.capability_allows("array", { can_sort_array = true }))
      assert.is_false(h.capability_allows("array", { can_sort_array = false }))
    end)

    it("refuses any unknown kind regardless of options", function()
      -- Outline contract names exactly two kinds; a builder that invented a
      -- third would silently slip through if this gate were permissive.
      assert.is_false(h.capability_allows("set", { can_sort_object = true, can_sort_array = true }))
    end)
  end)

  describe("sort_entries_by_position", function()
    local function entry(range)
      return { range = range, sort_key = tostring(range[1] * 100 + range[2]) }
    end

    it("orders entries by (start row, start col) ascending", function()
      local sorted = h.sort_entries_by_position({
        entry({ 2, 0, 2, 5 }),
        entry({ 0, 4, 0, 9 }),
        entry({ 0, 0, 0, 3 }),
        entry({ 1, 0, 1, 5 }),
      })
      assert.equals(0, sorted[1].range[1])
      assert.equals(0, sorted[1].range[2])
      assert.equals(0, sorted[2].range[1])
      assert.equals(4, sorted[2].range[2])
      assert.equals(1, sorted[3].range[1])
      assert.equals(2, sorted[4].range[1])
    end)

    it("does not mutate the input list", function()
      local input = {
        entry({ 5, 0, 5, 1 }),
        entry({ 0, 0, 0, 1 }),
      }
      h.sort_entries_by_position(input)
      assert.equals(5, input[1].range[1])
      assert.equals(0, input[2].range[1])
    end)
  end)

  describe("clamp_range_to_buffer (smoke)", function()
    local function make_buf(lines)
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      return bufnr
    end

    it("pulls a past-EOF end row back to the last real line's length", function()
      -- Treesitter reports a container range whose erow is line_count (one
      -- past the last real row). The applier feeds this straight to
      -- nvim_buf_get_text, which errors on out-of-bounds rows.
      local bufnr = make_buf({ "abc", "defgh" })
      local clamped = h.clamp_range_to_buffer(bufnr, { 0, 0, 2, 0 })
      assert.same({ 0, 0, 1, 5 }, clamped)
    end)

    it("trims an end column that overruns the row's actual length", function()
      local bufnr = make_buf({ "abc", "defgh" })
      local clamped = h.clamp_range_to_buffer(bufnr, { 0, 0, 1, 999 })
      assert.same({ 0, 0, 1, 5 }, clamped)
    end)

    it("returns the range untouched when it sits within the buffer", function()
      local bufnr = make_buf({ "abc", "defgh" })
      local clamped = h.clamp_range_to_buffer(bufnr, { 0, 1, 1, 3 })
      assert.same({ 0, 1, 1, 3 }, clamped)
    end)
  end)

  describe("collect_matches (smoke against the real JSON parser)", function()
    local function make_buf(lines)
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.bo[bufnr].filetype = "json"
      return bufnr
    end

    local json_query = [[
((object) @sortkeys.container (#set! sortkeys.kind "object"))
((array)  @sortkeys.container (#set! sortkeys.kind "array"))

((pair
   key:   (string (string_content) @sortkeys.key)
   value: (_)                       @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((array (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))
]]

    it("triages query matches into containers, entries, and a containers_by_key index", function()
      if not ts.has_parser("json") then
        pending("json treesitter parser not available")
        return
      end
      local bufnr = make_buf({ '{"b": 2, "a": 1}' })
      local parser = vim.treesitter.get_parser(bufnr, "json")
      local root = parser:parse()[1]:root()
      local query = vim.treesitter.query.parse("json", json_query)
      local containers, entries, comments, by_key = h.collect_matches(bufnr, root, query)
      assert.equals(1, #containers)
      assert.equals(2, #entries)
      assert.equals(0, #comments)
      -- by_key maps the container's node_id to the container record.
      local only = containers[1]
      assert.equals(only, by_key[only.node_key])
    end)
  end)
end)
