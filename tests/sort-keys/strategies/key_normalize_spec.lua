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

  describe("pkl(text)", function()
    it("returns a bare property identifier unchanged", function()
      assert.equals("name", key_normalize.pkl("name"))
    end)

    it("strips the surrounding double quotes of a mapping key string literal", function()
      -- Mapping entries spell their key as `["a"]`; the captured key node is
      -- the inner string literal `"a"`, which must collapse to `a`.
      assert.equals("a", key_normalize.pkl('"a"'))
    end)

    it("strips surrounding backticks of a quoted (keyword-escaped) identifier", function()
      -- Pkl wraps identifiers that collide with keywords in backticks, e.g.
      -- `` `default` = 1``; the sort_key is the bare word.
      assert.equals("default", key_normalize.pkl("`default`"))
    end)

    it("leaves inner characters of a string-literal key verbatim (v1 keeps escapes)", function()
      -- v1 only strips the delimiters; escape decoding is out of scope and
      -- round-tripping the literal text keeps the sort_key stable.
      assert.equals([[a\nb]], key_normalize.pkl([["a\nb"]]))
    end)

    it("preserves an empty quoted key", function()
      assert.equals("", key_normalize.pkl('""'))
    end)

    it("trims surrounding whitespace before deciding the surface form", function()
      assert.equals("a", key_normalize.pkl('  "a"  '))
    end)
  end)

  describe("kdl(text)", function()
    it("returns a bare node identifier unchanged", function()
      assert.equals("config", key_normalize.kdl("config"))
    end)

    it("keeps the dashes/dots a bare KDL identifier is allowed to contain", function()
      -- KDL bare identifiers admit `-`, `_`, `.` and more; none of them are
      -- delimiters here, so the whole name is the sort_key verbatim.
      assert.equals("foo-bar.baz", key_normalize.kdl("foo-bar.baz"))
    end)

    it("strips the surrounding double quotes of a quoted node name", function()
      assert.equals("bar baz", key_normalize.kdl('"bar baz"'))
    end)

    it('unescapes `\\"` to a literal double quote', function()
      assert.equals('a"b', key_normalize.kdl([["a\"b"]]))
    end)

    it("unescapes `\\\\` to a literal backslash", function()
      assert.equals("a\\b", key_normalize.kdl([["a\\b"]]))
    end)

    it("unescapes `\\/` to a literal forward slash", function()
      assert.equals("a/b", key_normalize.kdl([["a\/b"]]))
    end)

    it("unescapes `\\n` / `\\t` / `\\r` / `\\b` / `\\f` to their literal control bytes", function()
      assert.equals("a\nb", key_normalize.kdl([["a\nb"]]))
      assert.equals("a\tb", key_normalize.kdl([["a\tb"]]))
      assert.equals("a\rb", key_normalize.kdl([["a\rb"]]))
      assert.equals("\b", key_normalize.kdl([["\b"]]))
      assert.equals("\f", key_normalize.kdl([["\f"]]))
    end)

    it(
      "decodes a brace-delimited `\\u{E9}` escape to UTF-8 (KDL uses braces, not \\uXXXX)",
      function()
        -- KDL's unicode escape is `\u{1-6 hex}`, unlike JSON's fixed-width
        -- `\uXXXX`; U+00E9 encodes to the two UTF-8 bytes C3 A9.
        assert.equals("\xC3\xA9", key_normalize.kdl('"\\u{E9}"'))
      end
    )

    it("decodes a 5-hex `\\u{1F600}` astral escape to its 4-byte UTF-8 sequence", function()
      assert.equals("\xF0\x9F\x98\x80", key_normalize.kdl('"\\u{1F600}"'))
    end)

    it('takes a raw string `r"..."` body verbatim without escape processing', function()
      -- Raw strings disable escapes, so `\n` is the two literal bytes `\` `n`.
      assert.equals([[a\nb]], key_normalize.kdl([[r"a\nb"]]))
    end)

    it('strips the hash fence of a `r#"..."#` raw string and keeps inner quotes', function()
      assert.equals('a"b', key_normalize.kdl([[r#"a"b"#]]))
    end)

    it("preserves an empty quoted name", function()
      assert.equals("", key_normalize.kdl('""'))
    end)
  end)

  describe("python(text)", function()
    it("returns a bare identifier unchanged", function()
      -- Python dict keys can be identifiers when the dict is built from a
      -- variable, e.g. `{ x: 1 }` (rare in literals but valid).
      assert.equals("foo", key_normalize.python("foo"))
    end)

    it("returns an integer literal key as its surface text", function()
      -- `{ 42: "x" }` parses the key as an integer node; the sort compares
      -- string surface bytes, so the normalizer just hands back the digits.
      assert.equals("42", key_normalize.python("42"))
    end)

    it("returns a None / True / False key as its surface text", function()
      assert.equals("None", key_normalize.python("None"))
      assert.equals("True", key_normalize.python("True"))
      assert.equals("False", key_normalize.python("False"))
    end)

    it("strips double quotes around a string key", function()
      assert.equals("foo", key_normalize.python('"foo"'))
    end)

    it("strips single quotes around a string key", function()
      assert.equals("foo", key_normalize.python("'foo'"))
    end)

    it('strips triple double-quotes around a `"""foo"""` key', function()
      assert.equals("foo", key_normalize.python('"""foo"""'))
    end)

    it("strips triple single-quotes around a `'''foo'''` key", function()
      assert.equals("foo", key_normalize.python("'''foo'''"))
    end)

    it('unescapes `\\"` inside a double-quoted key to a literal double quote', function()
      assert.equals('a"b', key_normalize.python([["a\"b"]]))
    end)

    it("unescapes `\\'` inside a single-quoted key to a literal single quote", function()
      assert.equals("a'b", key_normalize.python("'a\\'b'"))
    end)

    it("unescapes `\\\\` to a single backslash", function()
      assert.equals("a\\b", key_normalize.python([["a\\b"]]))
    end)

    it(
      "unescapes `\\n` / `\\t` / `\\r` / `\\b` / `\\f` / `\\a` / `\\v` / `\\0` to their control bytes",
      function()
        assert.equals("a\nb", key_normalize.python([["a\nb"]]))
        assert.equals("a\tb", key_normalize.python([["a\tb"]]))
        assert.equals("a\rb", key_normalize.python([["a\rb"]]))
        assert.equals("\b", key_normalize.python([["\b"]]))
        assert.equals("\f", key_normalize.python([["\f"]]))
        assert.equals("\a", key_normalize.python([["\a"]]))
        assert.equals("\v", key_normalize.python([["\v"]]))
        assert.equals("\0", key_normalize.python([["\0"]]))
      end
    )

    it("decodes `\\xE9` (2 hex digits) to its UTF-8 byte sequence", function()
      -- Python's `\xNN` is exactly two hex digits; for U+00E9 in a regular
      -- string the runtime value is the codepoint, encoded UTF-8 as C3 A9.
      assert.equals("\xC3\xA9", key_normalize.python('"\\xE9"'))
    end)

    it("decodes `\\u00E9` (4 hex digits) to UTF-8", function()
      assert.equals("\xC3\xA9", key_normalize.python('"\\u00E9"'))
    end)

    it("decodes `\\U0001F600` (8 hex digits) to its 4-byte UTF-8 sequence", function()
      -- `\U` admits astral codepoints directly (no surrogate pair encoding).
      assert.equals("\xF0\x9F\x98\x80", key_normalize.python('"\\U0001F600"'))
    end)

    it('takes a raw string `r"..."` body verbatim without escape processing', function()
      -- Raw strings disable escapes: `\n` is the literal two bytes `\` `n`.
      assert.equals([[a\nb]], key_normalize.python([[r"a\nb"]]))
    end)

    it("treats the `r` prefix case-insensitively (`R'...'` is also raw)", function()
      assert.equals([[a\tb]], key_normalize.python([[R"a\tb"]]))
    end)

    it("strips the `b` bytes prefix and still decodes simple escapes", function()
      -- Bytes literals only accept \xNN (not \u/\U); for sort_key purposes
      -- the simple-escape decoding is enough and stays consistent.
      assert.equals("a\nb", key_normalize.python([[b"a\nb"]]))
    end)

    it("strips the `u` unicode prefix (no-op in Python 3, but legal syntax)", function()
      assert.equals("foo", key_normalize.python('u"foo"'))
    end)

    it("strips the `f` f-string prefix and leaves interpolation braces verbatim", function()
      -- f-string interpolation `{...}` is a runtime expression; v1 doesn't
      -- evaluate it. Keeping the braces in the sort_key gives a deterministic
      -- ordering that round-trips with the source spelling.
      assert.equals("hi {name}", key_normalize.python([[f"hi {name}"]]))
    end)

    it("treats `rb` / `br` raw-bytes prefix as raw (no escape processing)", function()
      assert.equals([[a\nb]], key_normalize.python([[rb"a\nb"]]))
      assert.equals([[a\nb]], key_normalize.python([[br"a\nb"]]))
    end)

    it("treats `fr` / `rf` raw-f-string prefix as raw", function()
      assert.equals([[hi \n {x}]], key_normalize.python([[fr"hi \n {x}"]]))
      assert.equals([[hi \n {x}]], key_normalize.python([[rf"hi \n {x}"]]))
    end)

    it("preserves an empty quoted key", function()
      assert.equals("", key_normalize.python('""'))
      assert.equals("", key_normalize.python("''"))
      assert.equals("", key_normalize.python('""""""'))
      assert.equals("", key_normalize.python("''''''"))
    end)
  end)

  describe("go(text)", function()
    it("returns a bare identifier (struct field) unchanged", function()
      -- Go struct fields and shorthand keyed-element keys arrive as bare
      -- identifiers; the surface text is the sort_key as-is.
      assert.equals("Foo", key_normalize.go("Foo"))
    end)

    it("strips the surrounding double quotes of an interpreted_string_literal", function()
      -- Map literal keys appear as `"key"`; strip quotes for sort_key
      -- comparison.
      assert.equals("foo", key_normalize.go('"foo"'))
    end)

    it("unescapes JSON-style escapes inside an interpreted_string_literal", function()
      -- Go interpreted strings use the same backslash set as JSON for the
      -- common escapes (\n, \t, \r, \\, \" and \uXXXX); decoding them is
      -- what makes "a\nb" and the two-byte literal `a\nb` compare equal
      -- under the same sort.
      assert.equals("a\nb", key_normalize.go([["a\nb"]]))
      assert.equals('a"b', key_normalize.go([["a\"b"]]))
      assert.equals("a\\b", key_normalize.go([["a\\b"]]))
    end)

    it("strips the surrounding backticks of a raw_string_literal", function()
      -- Go raw strings disable escape processing entirely: `a\nb` is the two
      -- literal bytes `\` and `n` inside, so we strip backticks without
      -- decoding.
      assert.equals("foo", key_normalize.go("`foo`"))
      assert.equals([[a\nb]], key_normalize.go("`a\\nb`"))
    end)

    it("preserves an empty quoted key", function()
      assert.equals("", key_normalize.go('""'))
      assert.equals("", key_normalize.go("``"))
    end)
  end)

  describe("rust(text)", function()
    it("returns a bare identifier unchanged", function()
      -- Rust struct fields and use_list entries arrive here as bare
      -- identifiers; the surface text is the sort_key as-is.
      assert.equals("foo", key_normalize.rust("foo"))
    end)

    it("keeps underscores and digits the Rust identifier grammar admits", function()
      assert.equals("snake_case_42", key_normalize.rust("snake_case_42"))
    end)

    it("strips the `r#` raw-identifier prefix so `r#type` sorts as `type`", function()
      -- Rust escapes keyword-collision identifiers as `r#type`, `r#match`,
      -- etc.; the semantic name is the bare word, so the sort_key must drop
      -- the prefix to compare correctly with non-raw siblings.
      assert.equals("type", key_normalize.rust("r#type"))
      assert.equals("match", key_normalize.rust("r#match"))
    end)

    it("strips `r#` at every component of a scoped path", function()
      -- Same logical import path may be written `foo::r#type` (when the leaf
      -- collides with a keyword) or `foo::bar`; both spellings must collapse
      -- to the same sort_key. `#` is not a legal identifier byte in Rust, so
      -- a global gsub cannot collide with a real identifier substring.
      assert.equals("foo::type", key_normalize.rust("foo::r#type"))
      assert.equals("foo::bar", key_normalize.rust("foo::r#bar"))
    end)

    it("returns a scoped use_list entry (`foo::bar`) verbatim", function()
      -- v1 treats use_list entries as element text — scoping `::` becomes
      -- part of the sort_key and the whole path compares lexicographically.
      assert.equals("foo::bar", key_normalize.rust("foo::bar"))
    end)

    it("returns `self` (the use-list self-import) verbatim", function()
      -- `use foo::{self, bar}` makes the leaf node literally `self`; it
      -- should sort by that surface text, not be confused with an identifier.
      assert.equals("self", key_normalize.rust("self"))
    end)
  end)

  describe("elixir(text)", function()
    it("strips the trailing colon of a keyword key (`name: ` → `name`)", function()
      -- The `keyword` node text carries the `:` and the space that follows it
      -- in `name: value`; the logical key is just the identifier.
      assert.equals("name", key_normalize.elixir("name: "))
      assert.equals("name", key_normalize.elixir("name:"))
    end)

    it('unquotes a quoted keyword key (`"foo bar": ` → `foo bar`)', function()
      assert.equals("foo bar", key_normalize.elixir('"foo bar": '))
    end)

    it("strips the leading colon of an atom key (`:foo` → `foo`)", function()
      -- Arrow-style map entries (`:foo => 1`) reach this layer as the raw
      -- atom text; the leading `:` is syntax, not part of the key.
      assert.equals("foo", key_normalize.elixir(":foo"))
    end)

    it('unquotes a quoted atom key (`:"foo bar"` → `foo bar`)', function()
      assert.equals("foo bar", key_normalize.elixir(':"foo bar"'))
    end)

    it('unquotes a bare string key (`"a"` → `a`)', function()
      -- Arrow-style entries with string keys (`\"a\" => 1`).
      assert.equals("a", key_normalize.elixir('"a"'))
    end)

    it("returns a bare identifier verbatim", function()
      assert.equals("snake_case_1", key_normalize.elixir("snake_case_1"))
    end)
  end)
end)
