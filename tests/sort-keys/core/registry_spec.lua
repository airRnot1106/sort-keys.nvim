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

    it("returns a handler that exposes `capabilities` and `outline` for typescript", function()
      local handler = registry.get("typescript")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
    end)

    it("the typescript handler declares can_sort_object / can_sort_array / can_deep", function()
      local handler = registry.get("typescript")
      assert.is_true(handler.capabilities.can_sort_object)
      assert.is_true(handler.capabilities.can_sort_array)
      assert.is_true(handler.capabilities.can_deep)
    end)

    it("the typescript handler declares comment_aware = true", function()
      local handler = registry.get("typescript")
      assert.is_true(handler.capabilities.comment_aware)
    end)

    it("returns a handler that exposes `capabilities` and `outline` for toml", function()
      local handler = registry.get("toml")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
    end)

    it("the toml handler declares can_sort_object / can_sort_array / can_deep", function()
      local handler = registry.get("toml")
      assert.is_true(handler.capabilities.can_sort_object)
      assert.is_true(handler.capabilities.can_sort_array)
      assert.is_true(handler.capabilities.can_deep)
    end)

    it("the toml handler declares comment_aware = true", function()
      local handler = registry.get("toml")
      assert.is_true(handler.capabilities.comment_aware)
    end)

    it("returns a handler that exposes `capabilities` and `outline` for nix", function()
      local handler = registry.get("nix")
      assert.is_not_nil(handler)
      assert.is_table(handler.capabilities)
      assert.is_function(handler.outline)
    end)

    it("the nix handler declares can_sort_object / can_sort_array / can_deep", function()
      local handler = registry.get("nix")
      assert.is_true(handler.capabilities.can_sort_object)
      assert.is_true(handler.capabilities.can_sort_array)
      assert.is_true(handler.capabilities.can_deep)
    end)

    it("the nix handler declares comment_aware = true", function()
      local handler = registry.get("nix")
      assert.is_true(handler.capabilities.comment_aware)
    end)
  end)

  describe("set_user_handlers(specs)", function()
    -- A trivial builder that records its config and returns a fixed outline.
    -- Built once per spec so each test can assert against a fresh instance.
    local function make_fake_builder()
      local fake = { captured = nil }
      function fake.build(_bufnr, _target, config)
        fake.captured = config
        return { kind = "object", range = { 0, 0, 0, 0 }, entries = {} }
      end
      return fake
    end

    local function noop_builder()
      return {
        build = function()
          return nil
        end,
      }
    end

    describe("adding a brand-new language", function()
      it("registers a handler for an unseen filetype", function()
        registry.set_user_handlers({
          foo = {
            filetypes = { "foo" },
            builder = noop_builder(),
            options = {
              can_sort_object = true,
              can_sort_array = true,
              can_deep = true,
              key_quoting = "logical",
              comment_aware = false,
            },
            query_text = "((object) @sortkeys.container)",
          },
        })
        local handler = registry.get("foo")
        assert.is_not_nil(handler)
        assert.is_true(handler.capabilities.can_sort_object)
        assert.is_false(handler.capabilities.comment_aware)
      end)

      it("passes the user-supplied query_text + options into the builder", function()
        local fake = make_fake_builder()
        registry.set_user_handlers({
          foo = {
            filetypes = { "foo" },
            builder = fake,
            options = {
              can_sort_object = true,
              can_sort_array = false,
              can_deep = false,
              key_quoting = "logical",
              comment_aware = false,
              structural_separator = ";",
            },
            query_text = "FOO_QUERY",
          },
        })
        registry.get("foo").outline(0, { kind = "cursor", pos = { 0, 0 } })
        assert.is_not_nil(fake.captured)
        assert.equals("FOO_QUERY", fake.captured.query_text)
        assert.equals(";", fake.captured.options.structural_separator)
      end)
    end)

    describe("partial override of a built-in", function()
      it(
        "merges only the `options` fields supplied by the user; the rest stays built-in",
        function()
          -- The built-in JSON handler declares comment_aware = false. Verify
          -- that overriding just that one field flips comment_aware to true
          -- without disturbing any other capability flag.
          registry.set_user_handlers({
            json = { options = { comment_aware = true } },
          })
          local handler = registry.get("json")
          assert.is_not_nil(handler)
          assert.is_true(handler.capabilities.comment_aware)
          assert.is_true(handler.capabilities.can_sort_object)
          assert.is_true(handler.capabilities.can_sort_array)
          assert.is_true(handler.capabilities.can_deep)
        end
      )

      it("uses the user-supplied builder when only `builder` is overridden", function()
        local fake = make_fake_builder()
        registry.set_user_handlers({
          json = { builder = fake },
        })
        registry.get("json").outline(0, { kind = "cursor", pos = { 0, 0 } })
        assert.is_not_nil(fake.captured)
        -- The built-in query_text + options were still passed through.
        assert.is_string(fake.captured.query_text)
        assert.is_true(fake.captured.options.can_sort_object)
      end)
    end)

    describe("conflicting filetype with a different config_name", function()
      it(
        "replaces the built-in entirely (no merge) when user config_name differs but filetype collides",
        function()
          local fake = make_fake_builder()
          registry.set_user_handlers({
            my_json = {
              filetypes = { "json" },
              builder = fake,
              options = {
                can_sort_object = true,
                can_sort_array = false,
                can_deep = false,
                key_quoting = "logical",
                comment_aware = false,
              },
              query_text = "MY_JSON_QUERY",
            },
          })
          registry.get("json").outline(0, { kind = "cursor", pos = { 0, 0 } })
          assert.is_not_nil(fake.captured)
          assert.equals("MY_JSON_QUERY", fake.captured.query_text)
          -- The built-in's can_sort_array=true must NOT bleed in.
          assert.is_false(fake.captured.options.can_sort_array)
        end
      )
    end)

    describe("non-overridden built-ins stay intact", function()
      it("does not affect other filetypes when user only overrides one", function()
        registry.set_user_handlers({
          json = { options = { comment_aware = true } },
        })
        local yaml_handler = registry.get("yaml")
        assert.is_not_nil(yaml_handler)
        assert.is_true(yaml_handler.capabilities.comment_aware) -- yaml's own default
      end)
    end)

    describe("clearing", function()
      it("removes all user handlers when called with an empty table", function()
        registry.set_user_handlers({
          foo = {
            filetypes = { "foo" },
            builder = noop_builder(),
            options = {
              can_sort_object = true,
              can_sort_array = true,
              can_deep = true,
              key_quoting = "logical",
              comment_aware = false,
            },
            query_text = "Q",
          },
        })
        assert.is_not_nil(registry.get("foo"))
        registry.set_user_handlers({})
        assert.is_nil(registry.get("foo"))
      end)

      it("treats nil the same as an empty table", function()
        registry.set_user_handlers({
          foo = {
            filetypes = { "foo" },
            builder = noop_builder(),
            options = {
              can_sort_object = true,
              can_sort_array = true,
              can_deep = true,
              key_quoting = "logical",
              comment_aware = false,
            },
            query_text = "Q",
          },
        })
        registry.set_user_handlers(nil)
        assert.is_nil(registry.get("foo"))
      end)

      it("clear leaves built-ins untouched", function()
        registry.set_user_handlers({ json = { options = { comment_aware = true } } })
        registry.set_user_handlers(nil)
        local json_handler = registry.get("json")
        assert.is_not_nil(json_handler)
        -- Back to built-in default
        assert.is_false(json_handler.capabilities.comment_aware)
      end)
    end)

    describe("validation for new-language specs", function()
      it("skips a new-language spec that is missing `builder`", function()
        registry.set_user_handlers({
          foo = {
            filetypes = { "foo" },
            options = {
              can_sort_object = true,
              can_sort_array = true,
              can_deep = true,
              key_quoting = "logical",
            },
            query_text = "Q",
          },
        })
        assert.is_nil(registry.get("foo"))
      end)

      it("skips a new-language spec that is missing `query_text`", function()
        registry.set_user_handlers({
          foo = {
            filetypes = { "foo" },
            builder = noop_builder(),
            options = {
              can_sort_object = true,
              can_sort_array = true,
              can_deep = true,
              key_quoting = "logical",
            },
          },
        })
        assert.is_nil(registry.get("foo"))
      end)

      it("skips a new-language spec that is missing `filetypes`", function()
        registry.set_user_handlers({
          foo = {
            builder = noop_builder(),
            options = {
              can_sort_object = true,
              can_sort_array = true,
              can_deep = true,
              key_quoting = "logical",
            },
            query_text = "Q",
          },
        })
        assert.is_nil(registry.get("foo"))
      end)

      it(
        "accepts a partial-override spec with only `options` (no builder/query_text needed)",
        function()
          registry.set_user_handlers({
            json = { options = { comment_aware = true } },
          })
          -- Should succeed because the built-in supplies the missing pieces.
          assert.is_not_nil(registry.get("json"))
        end
      )
    end)
  end)
end)
