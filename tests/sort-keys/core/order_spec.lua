local order = require("sort-keys.core.order")

local function e(key)
  return { sort_key = key }
end

describe("core.order", function()
  it("default comparator orders by sort_key bytewise ascending", function()
    local cmp = order.build({})
    assert.are.equal(-1, cmp(e("apple"), e("banana")))
    assert.are.equal(1, cmp(e("banana"), e("apple")))
    assert.are.equal(0, cmp(e("a"), e("a")))
  end)

  it("reverse (!) flips the comparison so the result descends", function()
    local cmp = order.build({ reverse = true })
    assert.are.equal(1, cmp(e("apple"), e("banana")))
    assert.are.equal(-1, cmp(e("banana"), e("apple")))
  end)

  it(
    "ignore_case (i) folds case so Banana sorts next to banana, not before all lowercase",
    function()
      -- Bytewise, 'B' (0x42) < 'a' (0x61), so without folding "Banana" would
      -- sort before "apple"; with folding it sorts after.
      local cmp = order.build({ ignore_case = true })
      assert.are.equal(1, cmp(e("Banana"), e("apple")))
    end
  )

  it("numeric (n) compares by the first number, so 9 sorts before 10", function()
    local cmp = order.build({ numeric = true })
    assert.are.equal(-1, cmp(e("item9"), e("item10")))
    assert.are.equal(1, cmp(e("item10"), e("item9")))
  end)

  it("pattern (r/pat/) compares by the first match, ignoring the rest of the key", function()
    -- Order by the trailing number captured via the pattern, not the prefix.
    local cmp = order.build({ pattern = "%d+" })
    assert.are.equal(-1, cmp(e("zzz1"), e("aaa2")))
  end)

  it("degrades to a plain sort instead of crashing on a malformed Lua pattern", function()
    -- A user typing `:SortKeys /(/` must not blow up the comparison with a
    -- "malformed pattern" error; the bad pattern is dropped and the full key
    -- is compared.
    local cmp = order.build({ pattern = "(" })
    assert.are.equal(-1, cmp(e("apple"), e("banana")))
  end)

  it("uses a custom comparator as the base, swapping the default key comparison", function()
    -- per architecture_sort_axes: a custom comparator injects at the ORDER base.
    -- Here it orders by key length instead of lexicographically.
    local cmp = order.build({
      comparator = function(a, b)
        return #a.sort_key < #b.sort_key
      end,
    })
    assert.are.equal(-1, cmp(e("a"), e("bbb")))
    assert.are.equal(1, cmp(e("bbb"), e("a")))
    assert.are.equal(0, cmp(e("xy"), e("zw")))
  end)

  it("falls back to the default comparison when the custom comparator returns nil", function()
    local cmp = order.build({
      comparator = function()
        return nil
      end,
    })
    assert.are.equal(-1, cmp(e("apple"), e("banana")))
  end)

  it("applies reverse (!) on top of a custom comparator", function()
    local cmp = order.build({
      reverse = true,
      comparator = function(a, b)
        return #a.sort_key < #b.sort_key
      end,
    })
    assert.are.equal(1, cmp(e("a"), e("bbb")))
  end)

  it("valid_pattern rejects malformed and empty patterns", function()
    assert.is_true(order.valid_pattern("%d+"))
    assert.is_false(order.valid_pattern("("))
    assert.is_false(order.valid_pattern("%"))
    assert.is_false(order.valid_pattern(""))
    assert.is_false(order.valid_pattern(nil))
  end)
end)
