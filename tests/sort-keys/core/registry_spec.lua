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
  end)
end)
