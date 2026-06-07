local sort = require("sort-keys.transform.sort")

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

  it(
    "deep-sorts an array of containers by their SORTED form (idempotent across re-extraction)",
    function()
      -- sort_keys here mirror what extract produces: the element's ORIGINAL
      -- (unsorted) text. Element A's child sorts to "{a, z}", B's stays "{m}".
      -- Ordering must follow the sorted form ("{a, z}" < "{m}" -> A first), not
      -- the original text ("{m}" < "{z, a}" -> B first), so a re-extracted second
      -- pass produces the same order.
      local function obj(entries)
        return {
          prefix = "{",
          suffix = "}",
          separator = ",",
          joint = " ",
          trailing = false,
          entries = entries,
        }
      end
      local childA = obj({ leaf("z"), leaf("a") })
      local childB = obj({ leaf("m") })
      local c = {
        prefix = "[",
        suffix = "]",
        separator = ",",
        joint = " ",
        trailing = false,
        entries = {
          {
            sort_key = "{z, a}",
            value_keyed = true,
            pre = "",
            post = "",
            movable = true,
            child = childA,
          },
          {
            sort_key = "{m}",
            value_keyed = true,
            pre = "",
            post = "",
            movable = true,
            child = childB,
          },
        },
      }
      local out = sort.sort(c, { order = {}, deep = true })
      assert.are.same({ "{a, z}", "{m}" }, keys(out))
    end
  )

  it("does not mutate the input container", function()
    local c = { entries = { leaf("c"), leaf("a") } }
    sort.sort(c, { order = {} })
    assert.are.same({ "c", "a" }, keys(c))
  end)
end)
