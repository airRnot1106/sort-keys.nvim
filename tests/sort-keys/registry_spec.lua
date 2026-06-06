-- registry.resolve reads the declarative packs off &runtimepath (no parser
-- needed), so these run anywhere the plugin is on the runtimepath.

local registry = require("sort-keys.registry")

describe("registry.resolve", function()
  after_each(function()
    registry.set_user_handlers({})
  end)

  it("resolves a built-in filetype to its declarative pack", function()
    local pack = registry.resolve("json")
    assert.are.equal("json", pack.config_name)
    assert.is_truthy(pack.query_text)
  end)

  it("returns nil for an unsupported filetype", function()
    assert.is_nil(registry.resolve("does_not_exist"))
  end)

  it(
    "applies a partial override keyed by a built-in config_name without restating filetypes",
    function()
      -- The whole point of a partial override: supply only options. The
      -- built-in's filetypes are inherited so the override actually binds.
      registry.set_user_handlers({ lua = { options = { comment_aware = false } } })
      local pack = registry.resolve("lua")
      assert.is_false(pack.options.comment_aware) -- overridden
      assert.are.equal("sort-keys.scm", pack.options.query_file) -- built-in option inherited
      assert.is_truthy(pack.query_text) -- query inherited, not dropped
    end
  )

  it("honors explicit filetypes on a spec keyed by a built-in config_name", function()
    -- Reuse the json pack for a new filetype; the base config is inherited.
    registry.set_user_handlers({ json = { filetypes = { "json5" }, options = {} } })
    assert.are.equal("json", registry.resolve("json5").config_name)
    assert.are.equal("json", registry.resolve("json").config_name) -- built-in still served
  end)

  it("does not register a brand-new config_name that omits filetypes", function()
    registry.set_user_handlers({ mylang = { options = {} } })
    assert.is_nil(registry.resolve("mylang"))
  end)

  it("loads a custom extractor for an irregular-AST pack and leaves it nil otherwise", function()
    local lua_pack = registry.resolve("lua")
    assert.is_truthy(lua_pack.extractor)
    assert.are.equal("function", type(lua_pack.extractor.extract))
    assert.is_nil(registry.resolve("json").extractor)
  end)
end)
