describe("sort-keys.strategies.key_normalize", function()
  local key_normalize

  before_each(function()
    package.loaded["sort-keys.strategies.key_normalize"] = nil
    key_normalize = require("sort-keys.strategies.key_normalize")
  end)

  describe("json(text)", function()
    it("strips the surrounding double quotes", function()
      assert.equals("foo", key_normalize.json('"foo"'))
    end)

    it("returns text unchanged when it has no surrounding quotes", function()
      -- handler may pass an already-unquoted `string_content` node.
      assert.equals("foo", key_normalize.json("foo"))
    end)

    it('unescapes `\\"` to a literal double quote', function()
      assert.equals('a"b', key_normalize.json([["a\"b"]]))
    end)

    it("unescapes `\\\\` to a literal backslash", function()
      assert.equals("a\\b", key_normalize.json([["a\\b"]]))
    end)

    it("unescapes `\\/` to a literal forward slash", function()
      assert.equals("a/b", key_normalize.json([["a\/b"]]))
    end)

    it("unescapes `\\n` to a literal LF byte", function()
      assert.equals("a\nb", key_normalize.json([["a\nb"]]))
    end)

    it("unescapes `\\r`, `\\t`, `\\b`, `\\f` to their literal control bytes", function()
      assert.equals("\r", key_normalize.json([["\r"]]))
      assert.equals("\t", key_normalize.json([["\t"]]))
      assert.equals("\b", key_normalize.json([["\b"]]))
      assert.equals("\f", key_normalize.json([["\f"]]))
    end)

    it("unescapes `\\u00E9` to UTF-8 \\xC3\\xA9 (BMP code point)", function()
      assert.equals("\xC3\xA9", key_normalize.json('"\\u00E9"'))
    end)

    it("decodes a high+low surrogate pair into the corresponding UTF-8 codepoint", function()
      -- U+1F600 GRINNING FACE = surrogate pair D83D DE00, UTF-8 = F0 9F 98 80.
      assert.equals("\xF0\x9F\x98\x80", key_normalize.json('"\\uD83D\\uDE00"'))
    end)

    it("preserves an empty string key", function()
      assert.equals("", key_normalize.json('""'))
    end)
  end)
end)
