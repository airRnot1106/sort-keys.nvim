-- The public API is intentionally only `:SortKeys` / `:DeepSortKeys`; any Lua
-- `sort` / `deep_sort` re-export would lock us into a second surface we have
-- to maintain. These tests fail-loud if such a leak appears.

describe("sort-keys (init) — public API surface", function()
  local sort_keys

  before_each(function()
    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    sort_keys = require("sort-keys")
  end)

  it("exposes setup", function()
    assert.is_function(sort_keys.setup)
  end)

  it("does not expose a Lua sort(opts) API", function()
    assert.is_nil(sort_keys.sort)
  end)

  it("does not expose a Lua deep_sort(opts) API", function()
    assert.is_nil(sort_keys.deep_sort)
  end)
end)
