local ir = require("sort-keys.core.ir")

describe("core.ir", function()
  describe("copy_entry", function()
    it("forwards every field so a new IR field is never silently dropped", function()
      local e = { sort_key = "a", text = '"a": 1', future_field = { nested = true } }
      local copy = ir.copy_entry(e)
      assert.are.same(e, copy)
    end)

    it("does not mutate the original when overrides are applied", function()
      local e = { sort_key = "a", movable = true }
      local copy = ir.copy_entry(e, { movable = false })
      assert.is_true(e.movable)
      assert.is_false(copy.movable)
    end)

    it("overrides win over the source field", function()
      local e = { child = nil, sort_key = "a" }
      local child = { kind = "object", entries = {} }
      local copy = ir.copy_entry(e, { child = child })
      assert.are.equal(child, copy.child)
    end)
  end)

  describe("copy_container", function()
    it("forwards framing fields and replaces entries without mutating the source", function()
      local c = { kind = "object", separator = ",", joint = "\n  ", entries = { 1, 2 } }
      local copy = ir.copy_container(c, { entries = { 9 } })
      assert.are.same({ 1, 2 }, c.entries)
      assert.are.same({ 9 }, copy.entries)
      assert.are.equal(",", copy.separator)
      assert.are.equal("\n  ", copy.joint)
    end)
  end)
end)
