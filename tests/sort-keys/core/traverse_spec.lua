local traverse = require("sort-keys.core.traverse")

-- a sortfn that reverses the entry list, so we can observe where it ran
local function reverse_entries(container)
  local rev = {}
  local n = #container.entries
  for i, e in ipairs(container.entries) do
    rev[n - i + 1] = e
  end
  local copy = {}
  for k, v in pairs(container) do
    copy[k] = v
  end
  copy.entries = rev
  return copy
end

local function keys(container)
  local out = {}
  for i, e in ipairs(container.entries) do
    out[i] = e.sort_key
  end
  return out
end

describe("core.traverse", function()
  it("shallow runs the sortfn on the container only", function()
    local c = { entries = { { sort_key = "a" }, { sort_key = "b" } } }
    local out = traverse.shallow(c, reverse_entries)
    assert.are.same({ "b", "a" }, keys(out))
  end)

  it("deep recurses post-order: a child is sorted before its parent reorders", function()
    local child = { entries = { { sort_key = "x" }, { sort_key = "y" } } }
    local c = {
      entries = {
        { sort_key = "a", child = child },
        { sort_key = "b" },
      },
    }
    local out = traverse.deep(c, reverse_entries)
    -- parent reordered:
    assert.are.same({ "b", "a" }, keys(out))
    -- the child (now at parent slot 2) was also reordered:
    assert.are.same({ "y", "x" }, keys(out.entries[2].child))
  end)

  it("deep does not mutate the input container or its child", function()
    local child = { entries = { { sort_key = "x" }, { sort_key = "y" } } }
    local c = { entries = { { sort_key = "a", child = child } } }
    traverse.deep(c, reverse_entries)
    assert.are.same({ "x", "y" }, keys(child))
    assert.are.same({ "a" }, keys(c))
  end)
end)
