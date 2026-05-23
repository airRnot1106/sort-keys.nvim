describe("sort-keys.core.registry", function()
  local registry

  before_each(function()
    package.loaded["sort-keys.core.registry"] = nil
    registry = require("sort-keys.core.registry")
  end)

  describe("get(filetype)", function()
    it("returns a handler that exposes `capabilities` and `outline` for json", function()
      local handler = registry.get("json")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
    end)

    it("the json handler declares can_sort_object / can_sort_array / can_deep", function()
      local handler = registry.get("json")
      assert.is_true(handler.capabilities.can_sort_object)
      assert.is_true(handler.capabilities.can_sort_array)
      assert.is_true(handler.capabilities.can_deep)
    end)

    it("the json handler declares comment_aware = false", function()
      local handler = registry.get("json")
      assert.is_false(handler.capabilities.comment_aware)
    end)

    -- Out of scope for this task: any other filetype must report "no handler"
    -- via nil so that command.lua can early-error with a notify.
    it("returns nil for filetypes that have no handler in this task scope", function()
      assert.is_nil(registry.get("python"))
      assert.is_nil(registry.get(""))
    end)

    it("returns a handler that exposes `capabilities` and `outline` for jsonc", function()
      local handler = registry.get("jsonc")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
    end)

    it("the jsonc handler declares can_sort_object / can_sort_array / can_deep", function()
      local handler = registry.get("jsonc")
      assert.is_true(handler.capabilities.can_sort_object)
      assert.is_true(handler.capabilities.can_sort_array)
      assert.is_true(handler.capabilities.can_deep)
    end)

    it("the jsonc handler declares comment_aware = true", function()
      local handler = registry.get("jsonc")
      assert.is_true(handler.capabilities.comment_aware)
    end)

    it("returns a handler that exposes `capabilities` and `outline` for yaml", function()
      local handler = registry.get("yaml")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
    end)

    it("the yaml handler declares can_sort_object / can_sort_array / can_deep", function()
      local handler = registry.get("yaml")
      assert.is_true(handler.capabilities.can_sort_object)
      assert.is_true(handler.capabilities.can_sort_array)
      assert.is_true(handler.capabilities.can_deep)
    end)

    it("the yaml handler declares comment_aware = true", function()
      local handler = registry.get("yaml")
      assert.is_true(handler.capabilities.comment_aware)
    end)

    it("yml resolves to the same handler shape as yaml", function()
      -- The `.yml` extension shares the YAML handler so users on either
      -- filename convention get the same behavior.
      local handler = registry.get("yml")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
      assert.is_true(handler.capabilities.can_sort_object)
    end)

    it("returns a handler that exposes `capabilities` and `outline` for javascript", function()
      local handler = registry.get("javascript")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
    end)

    it("the javascript handler declares can_sort_object / can_sort_array / can_deep", function()
      local handler = registry.get("javascript")
      assert.is_true(handler.capabilities.can_sort_object)
      assert.is_true(handler.capabilities.can_sort_array)
      assert.is_true(handler.capabilities.can_deep)
    end)

    it("the javascript handler declares comment_aware = true", function()
      local handler = registry.get("javascript")
      assert.is_true(handler.capabilities.comment_aware)
    end)

    it("returns a handler that exposes `capabilities` and `outline` for lua", function()
      local handler = registry.get("lua")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
    end)

    it("the lua handler declares can_sort_object / can_sort_array / can_deep", function()
      local handler = registry.get("lua")
      assert.is_true(handler.capabilities.can_sort_object)
      assert.is_true(handler.capabilities.can_sort_array)
      assert.is_true(handler.capabilities.can_deep)
    end)

    it("the lua handler declares comment_aware = true", function()
      local handler = registry.get("lua")
      assert.is_true(handler.capabilities.comment_aware)
    end)
  end)
end)
