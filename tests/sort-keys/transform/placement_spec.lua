local placement = require("sort-keys.transform.placement")

-- ascending-by-sort_key 3-way comparator, the placement specs' fixed order
local function asc(a, b)
  return (a.sort_key < b.sort_key and -1) or (a.sort_key > b.sort_key and 1) or 0
end

local function keys(entries)
  local out = {}
  for i, e in ipairs(entries) do
    out[i] = e.sort_key
  end
  return out
end

local function movable(key)
  return { sort_key = key, movable = true }
end

local function pin(key)
  return { sort_key = key, movable = false }
end

local function fence(key)
  return { sort_key = key, movable = false, fence = true }
end

describe("core.placement", function()
  it("sorts all entries when every entry is movable", function()
    local out = placement.arrange({ movable("c"), movable("a"), movable("b") }, asc)
    assert.are.same({ "a", "b", "c" }, keys(out))
  end)

  it("is stable: equal keys keep their source order", function()
    local first = { sort_key = "a", movable = true, tag = 1 }
    local second = { sort_key = "a", movable = true, tag = 2 }
    local out = placement.arrange({ second, first }, function()
      return 0
    end)
    assert.are.equal(2, out[1].tag)
    assert.are.equal(1, out[2].tag)
  end)

  it("keeps a plain pin at its slot but lets movable entries reorder across it", function()
    -- pin "z" sits at slot 2; movables b,a fill slots 1 and 3 in sorted order.
    local out = placement.arrange({ movable("b"), pin("z"), movable("a") }, asc)
    assert.are.same({ "a", "z", "b" }, keys(out))
  end)

  it("never lets a movable entry cross a fence", function()
    -- fence at slot 2 splits [b] | [d, c]; each segment sorts independently.
    local out = placement.arrange({ movable("b"), fence("z"), movable("d"), movable("c") }, asc)
    assert.are.same({ "b", "z", "c", "d" }, keys(out))
  end)

  it("models Visual partial sort: pinned outsiders hold, only free slots reorder", function()
    -- Entries outside a selection are flipped to movable=false (plain pins).
    -- Here slots 1 and 4 are pinned; only the inner two reorder.
    local out = placement.arrange({ pin("d"), movable("c"), movable("a"), pin("b") }, asc)
    assert.are.same({ "d", "a", "c", "b" }, keys(out))
  end)
end)
