-- Deep walk is post-order: children must be sorted before their parent, so
-- these specs assert both that the root is sorted AND that the nested
-- children are themselves sorted on the way out.

local function entry(key, anchor, child)
  return {
    kind = "pair",
    sort_key = key,
    range = { 0, 0, 0, 0 },
    movable = true,
    anchor = anchor,
    attached = {},
    child = child,
  }
end

local function outline_of(kind, entries)
  return {
    kind = kind,
    range = { 0, 0, 0, 0 },
    separator = ",",
    entries = entries,
  }
end

local function keys(o)
  local r = {}
  for i, e in ipairs(o.entries) do
    r[i] = e.sort_key
  end
  return r
end

describe("sort-keys.core.walker", function()
  local walker

  before_each(function()
    package.loaded["sort-keys.core.walker"] = nil
    walker = require("sort-keys.core.walker")
  end)

  describe("shallow walk (opts.deep == false)", function()
    it("sorts only the root Outline entries", function()
      local nested = outline_of("object", { entry("y", 1), entry("x", 2) })
      local root = outline_of("object", {
        entry("b", 1, nested),
        entry("a", 2),
      })
      local result = walker.walk(root, { deep = false, flags = {}, normalize_keys = true })
      assert.same({ "a", "b" }, keys(result))
      -- The nested child must be left untouched by a shallow walk; this is
      -- the only thing distinguishing shallow from deep at this layer.
      local b_entry
      for _, e in ipairs(result.entries) do
        if e.sort_key == "b" then
          b_entry = e
        end
      end
      assert.is_not_nil(b_entry)
      assert.is_not_nil(b_entry.child)
      assert.same({ "y", "x" }, keys(b_entry.child))
    end)
  end)

  describe("deep walk (opts.deep == true) — post-order recursion", function()
    it("sorts children before the parent", function()
      local nested = outline_of("object", { entry("y", 1), entry("x", 2) })
      local root = outline_of("object", {
        entry("b", 1, nested),
        entry("a", 2),
      })
      local result = walker.walk(root, { deep = true, flags = {}, normalize_keys = true })

      assert.same({ "a", "b" }, keys(result))

      local b_entry
      for _, e in ipairs(result.entries) do
        if e.sort_key == "b" then
          b_entry = e
        end
      end
      assert.is_not_nil(b_entry.child)
      assert.same({ "x", "y" }, keys(b_entry.child))
    end)

    it("preserves an entry's data_range when rebuilding it with the sorted child", function()
      -- Latent fragility: walker.rebuild_entry_with_child used to enumerate
      -- entry fields manually and would silently drop data_range — the
      -- comment_attach-recorded boundary the applier needs to splice
      -- inter-entry separators BEFORE an absorbed trailing comment. The
      -- bug was invisible only because applier's child-branch happens to
      -- recompute the suffix from entry.range minus child.range; any
      -- future change to that branch (or a new applier consumer of
      -- data_range on parent entries) would resurface the same separator
      -- placement issue we already fixed in apply_selection_overlay.
      local nested = outline_of("object", { entry("y", 1), entry("x", 2) })
      local parent = entry("b", 1, nested)
      parent.data_range = { 0, 0, 0, 1 }
      local root = outline_of("object", { parent, entry("a", 2) })

      local result = walker.walk(root, { deep = true, flags = {}, normalize_keys = true })

      local b_entry
      for _, e in ipairs(result.entries) do
        if e.sort_key == "b" then
          b_entry = e
        end
      end
      assert.same({ 0, 0, 0, 1 }, b_entry.data_range)
    end)

    it("propagates the same flags into nested children", function()
      local nested = outline_of("object", { entry("B", 1), entry("a", 2) })
      local root = outline_of("object", {
        entry("X", 1, nested),
        entry("a", 2),
      })
      local result = walker.walk(root, {
        deep = true,
        flags = { ignore_case = true },
        normalize_keys = true,
      })
      assert.same({ "a", "X" }, keys(result))

      local x_entry
      for _, e in ipairs(result.entries) do
        if e.sort_key == "X" then
          x_entry = e
        end
      end
      assert.same({ "a", "B" }, keys(x_entry.child))
    end)
  end)
end)
