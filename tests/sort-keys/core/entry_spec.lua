-- entry.copy is the single forward-compatible entry-copy helper that
-- replaces three previously-divergent implementations (comment_attach used
-- `for k,v in pairs(e)`; policy.apply_selection_overlay and
-- walker.rebuild_entry_with_child manually enumerated field names and
-- silently dropped any field not on the list). Pinning this contract here
-- prevents a future Outline field from re-introducing the drop-on-rebuild
-- bug class.

describe("sort-keys.core.entry", function()
  local entry

  before_each(function()
    package.loaded["sort-keys.core.entry"] = nil
    entry = require("sort-keys.core.entry")
  end)

  describe("copy(e)", function()
    it("returns a shallow copy carrying every field present on the input", function()
      local input = {
        kind = "pair",
        sort_key = "a",
        range = { 0, 1, 0, 4 },
        movable = true,
        anchor = 7,
        attached = { "x" },
        child = nil,
        data_range = { 0, 1, 0, 4 },
      }
      local out = entry.copy(input)
      assert.equals("pair", out.kind)
      assert.equals("a", out.sort_key)
      assert.equals(true, out.movable)
      assert.equals(7, out.anchor)
      assert.same({ 0, 1, 0, 4 }, out.range)
      assert.same({ "x" }, out.attached)
      assert.same({ 0, 1, 0, 4 }, out.data_range)
    end)

    it("forwards an unknown future field without enumerating it", function()
      -- The whole point of the forward-compat copy: a future Outline field
      -- the helper has never heard of must survive the round-trip.
      local input = { kind = "pair", sort_key = "x", future_field = 42 }
      local out = entry.copy(input)
      assert.equals(42, out.future_field)
    end)

    it("returns a distinct table so mutating the copy does not affect the input", function()
      -- Field-level shallow copy is enough for the rebuild call sites; deep
      -- copying range/data_range is the caller's responsibility (only
      -- comment_attach needs that because it mutates ranges in place).
      local input = { kind = "pair", sort_key = "a", anchor = 1 }
      local out = entry.copy(input)
      out.anchor = 99
      assert.equals(1, input.anchor)
    end)
  end)

  describe("copy(e, overrides)", function()
    it("applies the overrides on top of the copied fields", function()
      local input = { kind = "pair", sort_key = "a", movable = true, anchor = 1 }
      local out = entry.copy(input, { movable = false })
      assert.equals(false, out.movable)
      -- Non-overridden fields stay intact.
      assert.equals("a", out.sort_key)
      assert.equals(1, out.anchor)
    end)

    it("introduces a new field present only in overrides", function()
      -- This is the shape walker.rebuild_entry_with_child uses: copy + child.
      local input = { kind = "pair", sort_key = "a", child = nil }
      local sorted_child = { kind = "object", entries = {} }
      local out = entry.copy(input, { child = sorted_child })
      assert.equals(sorted_child, out.child)
    end)

    it("does not mutate the input when overrides are supplied", function()
      local input = { kind = "pair", sort_key = "a", movable = true }
      entry.copy(input, { movable = false })
      assert.equals(true, input.movable)
    end)

    it("treats an empty overrides table the same as no overrides", function()
      local input = { kind = "pair", sort_key = "a", anchor = 1 }
      local out = entry.copy(input, {})
      assert.equals("a", out.sort_key)
      assert.equals(1, out.anchor)
    end)
  end)
end)
