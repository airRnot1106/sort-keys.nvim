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

  describe("handlers", function()
    -- These specs prove the config → registry wiring. They reload the
    -- registry between cases so a stale USER_SPECS from a prior test
    -- cannot bleed across describes.
    local registry

    before_each(function()
      package.loaded["sort-keys.core.registry"] = nil
      registry = require("sort-keys.core.registry")
    end)

    it("defaults handlers to an empty table", function()
      assert.same({}, config.defaults.handlers)
    end)

    it("forwards setup({handlers={...}}) into the registry as user handlers", function()
      local fake = { build = function() end }
      config.setup({
        handlers = {
          my_lang = {
            filetypes = { "my_lang" },
            builder = fake,
            options = {
              can_sort_object = true,
              can_sort_array = true,
              can_deep = true,
              key_quoting = "logical",
              comment_aware = false,
            },
            query_text = "Q",
          },
        },
      })
      assert.is_not_nil(registry.get("my_lang"))
    end)

    it("calling setup({}) again clears previously registered user handlers", function()
      config.setup({
        handlers = {
          my_lang = {
            filetypes = { "my_lang" },
            builder = { build = function() end },
            options = {
              can_sort_object = true,
              can_sort_array = true,
              can_deep = true,
              key_quoting = "logical",
              comment_aware = false,
            },
            query_text = "Q",
          },
        },
      })
      assert.is_not_nil(registry.get("my_lang"))
      config.setup({})
      assert.is_nil(registry.get("my_lang"))
    end)
  end)
end)
