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

  it("deep recomputes a value_keyed entry's sort_key from its SORTED child", function()
    -- An array element's ordering key is its own content. Deep sort rewrites
    -- that content, so the key must be re-derived from the sorted child;
    -- otherwise a second pass (re-extracting the key from the now-reordered
    -- text) would order the array differently — i.e. deep sort is not idempotent.
    local child = {
      prefix = "{",
      suffix = "}",
      separator = ",",
      joint = " ",
      trailing = false,
      entries = { { sort_key = "z", text = "z" }, { sort_key = "a", text = "a" } },
    }
    local c = {
      entries = {
        { sort_key = "{z, a}", value_keyed = true, pre = "", post = "", child = child },
      },
    }
    local out = traverse.deep(c, reverse_entries)
    -- reverse_entries flips the child to [a, z]; the key reflects that order.
    assert.are.equal("{a, z}", out.entries[1].sort_key)
  end)

  it("deep leaves a pair entry's sort_key (its key) untouched when recursing", function()
    -- A pair entry sorts by its KEY, not its value text, so recursion into the
    -- value container must never overwrite the key.
    local child = {
      prefix = "{",
      suffix = "}",
      separator = ",",
      joint = " ",
      trailing = false,
      entries = { { sort_key = "z", text = "z" }, { sort_key = "a", text = "a" } },
    }
    local c = {
      entries = {
        { sort_key = "b", pre = '"b": ', post = "", child = child },
      },
    }
    local out = traverse.deep(c, reverse_entries)
    assert.are.equal("b", out.entries[1].sort_key)
  end)

  it("deep does not mutate the input container or its child", function()
    local child = { entries = { { sort_key = "x" }, { sort_key = "y" } } }
    local c = { entries = { { sort_key = "a", child = child } } }
    traverse.deep(c, reverse_entries)
    assert.are.same({ "x", "y" }, keys(child))
    assert.are.same({ "a" }, keys(c))
  end)
end)
