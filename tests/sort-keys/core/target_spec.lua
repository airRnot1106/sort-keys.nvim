-- Cmdline [range] is intentionally absent from Target; the dispatcher must
-- derive position from cursor / visual marks, not from `user_command opts`.

describe("sort-keys.core.target", function()
  local target

  before_each(function()
    package.loaded["sort-keys.core.target"] = nil
    target = require("sort-keys.core.target")
  end)

  describe("from_normal", function()
    it("returns a cursor Target with the 0-indexed row/col pair", function()
      local t = target.from_normal({ 0, 4 })
      assert.equals("cursor", t.kind)
      assert.same({ 0, 4 }, t.pos)
    end)
  end)

  describe("from_visual", function()
    it("returns a selection Target whose range is a 4-tuple", function()
      local t = target.from_visual({ 0, 1, 0, 8 })
      assert.equals("selection", t.kind)
      assert.same({ 0, 1, 0, 8 }, t.range)
    end)
  end)

  describe("cmdline [range] is ignored", function()
    -- This is a documentation-style guard: target.from_normal/from_visual
    -- accept only their own input shape, never a line1/line2 tuple from
    -- `user_command opts`. We assert the public API does NOT carry a `line1`
    -- or `line2` field through to the returned Target.
    it("never propagates a cmdline range into the cursor Target", function()
      local t = target.from_normal({ 2, 0 })
      assert.is_nil(t.line1)
      assert.is_nil(t.line2)
    end)
  end)
end)
