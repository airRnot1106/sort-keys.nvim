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

  describe("yaml(text)", function()
    it("returns a bare scalar unchanged", function()
      assert.equals("foo", key_normalize.yaml("foo"))
    end)

    it("trims surrounding whitespace from a bare scalar", function()
      -- The treesitter node text for a YAML bare key sometimes carries a
      -- leading space when the node range starts after the indent; the
      -- normalizer should produce a canonical key regardless.
      assert.equals("foo", key_normalize.yaml("  foo  "))
    end)

    it("strips single quotes around a quoted bare scalar", function()
      assert.equals("foo", key_normalize.yaml("'foo'"))
    end)

    it("unescapes `''` inside a single-quoted key to a literal `'`", function()
      -- YAML's only escape inside single quotes: double the quote.
      assert.equals("a'b", key_normalize.yaml("'a''b'"))
    end)

    it("strips double quotes around a double-quoted scalar", function()
      assert.equals("foo", key_normalize.yaml('"foo"'))
    end)

    it('unescapes JSON-style `\\"` inside a double-quoted key', function()
      assert.equals('a"b', key_normalize.yaml([["a\"b"]]))
    end)

    it("unescapes `\\n` inside a double-quoted key to a literal LF byte", function()
      assert.equals("a\nb", key_normalize.yaml([["a\nb"]]))
    end)

    it("decodes a `\\u00E9` escape inside a double-quoted key to UTF-8", function()
      assert.equals("\xC3\xA9", key_normalize.yaml('"\\u00E9"'))
    end)

    it("decodes a surrogate pair inside a double-quoted key", function()
      assert.equals("\xF0\x9F\x98\x80", key_normalize.yaml('"\\uD83D\\uDE00"'))
    end)

    it("preserves an empty quoted key", function()
      assert.equals("", key_normalize.yaml('""'))
      assert.equals("", key_normalize.yaml("''"))
    end)
  end)

  describe("js(text)", function()
    it("returns a bare identifier unchanged", function()
      assert.equals("foo", key_normalize.js("foo"))
    end)

    it("strips double quotes around a quoted key", function()
      assert.equals("foo", key_normalize.js('"foo"'))
    end)

    it("strips single quotes around a quoted key", function()
      assert.equals("foo", key_normalize.js("'foo'"))
    end)

    it('unescapes `\\"` inside a double-quoted key', function()
      assert.equals('a"b', key_normalize.js([["a\"b"]]))
    end)

    it("unescapes `\\'` inside a single-quoted key", function()
      assert.equals("a'b", key_normalize.js("'a\\'b'"))
    end)

    it("unescapes `\\n` inside a double-quoted key to a literal LF byte", function()
      assert.equals("a\nb", key_normalize.js([["a\nb"]]))
    end)

    it("returns a numeric literal key as its surface text", function()
      -- JS object keys like `{ 42: "x" }` parse as numeric nodes; the sort
      -- compares them as strings, so the normalizer just returns the digits.
      assert.equals("42", key_normalize.js("42"))
    end)

    it("preserves an empty quoted key", function()
      assert.equals("", key_normalize.js('""'))
      assert.equals("", key_normalize.js("''"))
    end)
  end)

  describe("lua(text)", function()
    it("returns a bare identifier unchanged", function()
      assert.equals("foo", key_normalize.lua("foo"))
    end)

    it("strips double quotes around a quoted key", function()
      assert.equals("foo", key_normalize.lua('"foo"'))
    end)

    it("strips single quotes around a quoted key", function()
      assert.equals("foo", key_normalize.lua("'foo'"))
    end)

    it('unescapes `\\"` inside a double-quoted key', function()
      assert.equals('a"b', key_normalize.lua([["a\"b"]]))
    end)

    it("unescapes `\\'` inside a single-quoted key", function()
      assert.equals("a'b", key_normalize.lua("'a\\'b'"))
    end)

    it("unescapes `\\n` / `\\t` / `\\r` to their literal control bytes", function()
      assert.equals("a\nb", key_normalize.lua([["a\nb"]]))
      assert.equals("a\tb", key_normalize.lua([["a\tb"]]))
      assert.equals("a\rb", key_normalize.lua([["a\rb"]]))
    end)

    it("unescapes `\\\\` to a single backslash", function()
      assert.equals("a\\b", key_normalize.lua([["a\\b"]]))
    end)

    it("strips a long-bracket key `[[foo]]` and treats inner bytes literally", function()
      -- Lua long brackets do not process escape sequences; `\n` inside `[[...]]`
      -- is the two literal bytes `\` and `n`, not a newline.
      assert.equals("foo", key_normalize.lua("[[foo]]"))
      assert.equals("a\\nb", key_normalize.lua("[[a\\nb]]"))
    end)

    it("strips a level-N long bracket `[==[foo]==]`", function()
      assert.equals("foo", key_normalize.lua("[==[foo]==]"))
    end)

    it("preserves an empty quoted key", function()
      assert.equals("", key_normalize.lua('""'))
      assert.equals("", key_normalize.lua("''"))
    end)
  end)

  describe("toml(text)", function()
    it("returns a bare key unchanged", function()
      assert.equals("foo", key_normalize.toml("foo"))
    end)

    it("strips double quotes around a basic-string key", function()
      assert.equals("foo", key_normalize.toml('"foo"'))
    end)

    it("strips single quotes around a literal-string key", function()
      assert.equals("foo", key_normalize.toml("'foo'"))
    end)

    it('unescapes `\\"` inside a basic-string key', function()
      assert.equals('a"b', key_normalize.toml([["a\"b"]]))
    end)

    it("unescapes `\\n` / `\\t` / `\\r` inside a basic-string key", function()
      assert.equals("a\nb", key_normalize.toml([["a\nb"]]))
      assert.equals("a\tb", key_normalize.toml([["a\tb"]]))
      assert.equals("a\rb", key_normalize.toml([["a\rb"]]))
    end)

    it("decodes `\\u00E9` inside a basic-string key to UTF-8", function()
      assert.equals("\xC3\xA9", key_normalize.toml('"\\u00E9"'))
    end)

    it("treats backslash inside a literal-string key as a literal byte", function()
      -- TOML literal strings (single quotes) do NOT process escapes; `\n`
      -- inside `'...'` is the two literal bytes `\` and `n`.
      assert.equals("a\\nb", key_normalize.toml("'a\\nb'"))
    end)

    it("returns a dotted-key text unchanged so the dots become part of the sort_key", function()
      -- v1 treats `a.b.c` as one flat sort_key rather than recursing into
      -- nested tables. Keeping the dots in the returned string lets callers
      -- compare dotted keys lexicographically as a unit.
      assert.equals("a.b.c", key_normalize.toml("a.b.c"))
    end)

    it("returns a dotted key with quoted segment unchanged at this layer", function()
      -- Mixed dotted keys (`a."b.c"`) are returned verbatim; per-segment
      -- normalization is out of scope for v1 and would force the sort_key to
      -- diverge from the source spelling.
      assert.equals('a."b.c"', key_normalize.toml('a."b.c"'))
    end)

    it("preserves an empty quoted key", function()
      assert.equals("", key_normalize.toml('""'))
      assert.equals("", key_normalize.toml("''"))
    end)
  end)

  describe("nix(text)", function()
    it("returns a bare identifier unchanged", function()
      assert.equals("foo", key_normalize.nix("foo"))
    end)

    it("returns a dotted attrpath verbatim so the dots become part of the sort_key", function()
      -- Same precedent as TOML: v1 keeps `a.b.c` as one flat sort_key rather
      -- than recursing into nested attrsets.
      assert.equals("a.b.c", key_normalize.nix("a.b.c"))
    end)

    it("strips double quotes around a basic-string key", function()
      assert.equals("foo", key_normalize.nix('"foo"'))
    end)

    it('unescapes `\\"` inside a basic-string key', function()
      assert.equals('a"b', key_normalize.nix([["a\"b"]]))
    end)

    it("unescapes `\\n` / `\\t` / `\\r` inside a basic-string key", function()
      assert.equals("a\nb", key_normalize.nix([["a\nb"]]))
      assert.equals("a\tb", key_normalize.nix([["a\tb"]]))
      assert.equals("a\rb", key_normalize.nix([["a\rb"]]))
    end)

    it("unescapes `\\\\` to a single backslash", function()
      assert.equals("a\\b", key_normalize.nix([["a\\b"]]))
    end)

    it("unescapes `\\$` to a literal `$` (Nix-specific escape)", function()
      -- Nix string-fragment-escape adds `\$` so a key can hold a literal `$`
      -- without triggering anti-quotation (`${...}`).
      assert.equals("a$b", key_normalize.nix([["a\$b"]]))
    end)

    it("preserves an empty quoted key", function()
      assert.equals("", key_normalize.nix('""'))
    end)

    it("returns a dotted attrpath with a quoted segment verbatim at this layer", function()
      -- Mixed `a."b.c".d` is rare and per-segment normalization is out of
      -- scope for v1; round-tripping the literal text keeps sort_key stable
      -- with the source spelling.
      assert.equals('a."b.c".d', key_normalize.nix('a."b.c".d'))
    end)
  end)
end)
