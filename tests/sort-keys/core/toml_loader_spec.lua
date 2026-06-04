-- Pinned subset: only `key = "string"` and `key = true/false` are in scope;
-- any TOML feature beyond that must raise rather than silently parse, since
-- the handler files rely on the strict shape.

local function with_tmp(content, fn)
  local path = vim.fn.tempname() .. ".toml"
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
  local ok, err = pcall(fn, path)
  os.remove(path)
  if not ok then
    error(err)
  end
end

describe("sort-keys.core.toml_loader", function()
  local loader

  before_each(function()
    package.loaded["sort-keys.core.toml_loader"] = nil
    loader = require("sort-keys.core.toml_loader")
  end)

  describe("parse(text)", function()
    it('reads a `key = "value"` string pair', function()
      local t = loader.parse('description = "JSON handler"\n')
      assert.equals("JSON handler", t.description)
    end)

    it("reads `key = true` and `key = false` boolean pairs", function()
      local t = loader.parse("can_sort_object = true\ncan_deep = false\n")
      assert.is_true(t.can_sort_object)
      assert.is_false(t.can_deep)
    end)

    it("ignores blank lines and `#` line comments", function()
      local text = table.concat({
        "# top comment",
        "",
        "can_sort_array = true",
        "# trailing block",
        "",
      }, "\n")
      local t = loader.parse(text)
      assert.is_true(t.can_sort_array)
    end)

    it("preserves the contents of a string value verbatim (no escape collapse)", function()
      -- Whitespace and punctuation in string values must round-trip; this is
      -- how `structural_separator = ", "` style declarations stay intact.
      local t = loader.parse('structural_separator = ", "\n')
      assert.equals(", ", t.structural_separator)
    end)

    it("strips an inline `#` comment after a string value", function()
      local t = loader.parse('structural_separator = "," # trailing comment\n')
      assert.equals(",", t.structural_separator)
    end)

    it("strips an inline `#` comment after a boolean value", function()
      local t = loader.parse("can_deep = true # only when nested\n")
      assert.is_true(t.can_deep)
    end)

    it("keeps a `#` that sits inside the string value", function()
      -- The inline-comment stripper must not fire on a `#` between the quotes;
      -- it is part of the value, not a comment.
      local t = loader.parse('key_quoting = "a # b"\n')
      assert.equals("a # b", t.key_quoting)
    end)

    it("errors on malformed input (no `=`)", function()
      assert.has_error(function()
        loader.parse("can_sort_object true\n")
      end)
    end)
  end)

  describe("load(path)", function()
    it("returns the parsed table for an existing file", function()
      with_tmp('description = "X"\ncan_deep = true\n', function(path)
        local t = loader.load(path)
        assert.equals("X", t.description)
        assert.is_true(t.can_deep)
      end)
    end)

    it("errors when the file does not exist (Fail Fast)", function()
      assert.has_error(function()
        loader.load("/nonexistent/path/to/missing.toml")
      end)
    end)
  end)
end)
