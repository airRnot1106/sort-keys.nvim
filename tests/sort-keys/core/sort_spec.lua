local sort = require("sort-keys.core.sort")

local function leaf(key)
  return { sort_key = key, text = key, movable = true, anchor = 0 }
end

local function keys(container)
  local out = {}
  for i, e in ipairs(container.entries) do
    out[i] = e.sort_key
  end
  return out
end

describe("core.sort", function()
  it("composes order + placement: shallow ascending sort", function()
    local c = { entries = { leaf("c"), leaf("a"), leaf("b") } }
    local out = sort.sort(c, { order = {} })
    assert.are.same({ "a", "b", "c" }, keys(out))
  end)

  it("passes the order spec through to the comparator (reverse)", function()
    local c = { entries = { leaf("a"), leaf("c"), leaf("b") } }
    local out = sort.sort(c, { order = { reverse = true } })
    assert.are.same({ "c", "b", "a" }, keys(out))
  end)

  it("deep sorts children before parents and leaves framing fields intact", function()
    local child = { separator = ",", entries = { leaf("y"), leaf("x") } }
    local c = {
      separator = ",",
      entries = {
        { sort_key = "b", text = "b", movable = true, child = child },
        leaf("a"),
      },
    }
    local out = sort.sort(c, { order = {}, deep = true })
    assert.are.same({ "a", "b" }, keys(out))
    -- "b" with its child is now at slot 2, and the child got sorted too
    assert.are.same({ "x", "y" }, keys(out.entries[2].child))
    assert.are.equal(",", out.separator)
  end)

  it("does not mutate the input container", function()
    local c = { entries = { leaf("c"), leaf("a") } }
    sort.sort(c, { order = {} })
    assert.are.same({ "c", "a" }, keys(c))
  end)
end)
