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
end)
