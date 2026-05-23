describe("sort-keys.config", function()
  local config

  before_each(function()
    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    config = require("sort-keys.config")
  end)

  it("exposes a defaults table", function()
    assert.is_table(config.defaults)
  end)

  it("merges user options on top of defaults", function()
    config.setup({ custom = true })
    assert.is_true(config.options.custom)
  end)

  it("defaults normalize_keys to true", function()
    assert.is_true(config.defaults.normalize_keys)
    assert.is_true(config.options.normalize_keys)
  end)

  it("defaults comparator to nil", function()
    assert.is_nil(config.defaults.comparator)
    assert.is_nil(config.options.comparator)
  end)

  it("accepts normalize_keys = false via setup", function()
    config.setup({ normalize_keys = false })
    assert.is_false(config.options.normalize_keys)
  end)

  it("accepts a comparator function via setup", function()
    local cmp = function(a, b, _ctx)
      return a < b
    end
    config.setup({ comparator = cmp })
    assert.equals(cmp, config.options.comparator)
  end)
end)
