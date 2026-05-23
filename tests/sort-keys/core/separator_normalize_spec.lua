-- Pure-string policy for inter-entry separators.
--
-- Operates on the (pieces, gaps) pair the applier builds without touching
-- the buffer or the AST. The policy enforces two contracts that depend on
-- the host language's separator capability:
--   * Every non-last position must have exactly one separator between the
--     pieces (carried in the gap or at the piece's tail). If neither side
--     has one, the gap gains a leading separator.
--   * The last piece must (or must not) end in a trailing separator, based
--     on `trailing_separator_allowed`.

describe("sort-keys.core.separator_normalize", function()
  local separator_normalize

  before_each(function()
    package.loaded["sort-keys.core.separator_normalize"] = nil
    separator_normalize = require("sort-keys.core.separator_normalize")
  end)

  local opts_json = { separator = ",", trailing_separator_allowed = false }
  local opts_jsonc = { separator = ",", trailing_separator_allowed = true }

  describe("normalize(pieces, gaps, opts)", function()
    it("leaves a clean pieces/gaps pair unchanged", function()
      local pieces, gaps = separator_normalize.normalize(
        { '"a": 1', '"b": 2' },
        { ", " },
        opts_json
      )
      assert.same({ '"a": 1', '"b": 2' }, pieces)
      assert.same({ ", " }, gaps)
    end)

    it("inserts a separator at the start of a gap that lacks one", function()
      local pieces, gaps = separator_normalize.normalize(
        { '"a": 1', '"b": 2' },
        { "\n  " },
        opts_json
      )
      assert.same({ '"a": 1', '"b": 2' }, pieces)
      assert.same({ ",\n  " }, gaps)
    end)

    it("does not double-insert when the previous piece already ends with the separator", function()
      local pieces, gaps = separator_normalize.normalize(
        { '"a": 1,', '"b": 2' },
        { "\n  " },
        opts_json
      )
      assert.same({ '"a": 1,', '"b": 2' }, pieces)
      assert.same({ "\n  " }, gaps)
    end)

    it("does not double-insert when the gap already contains the separator anywhere", function()
      local pieces, gaps = separator_normalize.normalize(
        { '"a": 1', '"b": 2' },
        { "  ,\n  " },
        opts_json
      )
      assert.same({ '"a": 1', '"b": 2' }, pieces)
      assert.same({ "  ,\n  " }, gaps)
    end)

    it("strips a trailing separator from the last piece when the language forbids it", function()
      local pieces, gaps = separator_normalize.normalize(
        { '"a": 1', '"b": 2,' },
        { ", " },
        opts_json
      )
      assert.same({ '"a": 1', '"b": 2' }, pieces)
      assert.same({ ", " }, gaps)
    end)

    it("keeps the trailing separator on the last piece when the language allows it", function()
      local pieces, gaps = separator_normalize.normalize(
        { '"a": 1', '"b": 2,' },
        { ", " },
        opts_jsonc
      )
      assert.same({ '"a": 1', '"b": 2,' }, pieces)
      assert.same({ ", " }, gaps)
    end)

    it("ignores an internal separator that is followed by other content (not a tail)", function()
      -- The structural comma is in the middle of the piece (pair + comma +
      -- trailing block comment). It is NOT the piece's tail, so a "strip
      -- trailing separator" rule must not touch it.
      local pieces, gaps = separator_normalize.normalize(
        { '"a": 1', '"b": 2, /* T */' },
        { "\n  " },
        opts_json
      )
      assert.same({ '"a": 1', '"b": 2, /* T */' }, pieces)
      assert.same({ ",\n  " }, gaps)
    end)

    it("does not mutate the input arrays", function()
      local in_pieces = { '"a": 1', '"b": 2' }
      local in_gaps = { "\n  " }
      separator_normalize.normalize(in_pieces, in_gaps, opts_json)
      assert.same({ '"a": 1', '"b": 2' }, in_pieces)
      assert.same({ "\n  " }, in_gaps)
    end)

    it("is a no-op for a single piece (no gaps to fill)", function()
      local pieces, gaps = separator_normalize.normalize({ '"a": 1' }, {}, opts_json)
      assert.same({ '"a": 1' }, pieces)
      assert.same({}, gaps)
    end)

    it("strips trailing separator from a single piece when forbidden", function()
      local pieces, gaps = separator_normalize.normalize({ '"a": 1,' }, {}, opts_json)
      assert.same({ '"a": 1' }, pieces)
      assert.same({}, gaps)
    end)

    it("is agnostic to the separator character (e.g., Lua-style `;`)", function()
      -- Pin the contract that the policy treats `separator` as an opaque
      -- string. No comma-specific logic must leak into the module.
      local pieces, gaps = separator_normalize.normalize(
        { "a = 1", "b = 2" },
        { "\n  " },
        { separator = ";", trailing_separator_allowed = false }
      )
      assert.same({ "a = 1", "b = 2" }, pieces)
      assert.same({ ";\n  " }, gaps)
    end)

    describe("whitespace-only separators (e.g., a literal space or newline)", function()
      it("inserts a literal space when neither side already carries one", function()
        local pieces, gaps = separator_normalize.normalize(
          { "alpha", "beta" },
          { "" },
          { separator = " ", trailing_separator_allowed = false }
        )
        assert.same({ "alpha", "beta" }, pieces)
        assert.same({ " " }, gaps)
      end)

      it("does not double-insert when the previous piece already ends with the space", function()
        local pieces, gaps = separator_normalize.normalize(
          { "alpha ", "beta" },
          { "" },
          { separator = " ", trailing_separator_allowed = false }
        )
        assert.same({ "alpha ", "beta" }, pieces)
        assert.same({ "" }, gaps)
      end)

      it("strips a trailing whitespace separator from the last piece when forbidden", function()
        local pieces, gaps = separator_normalize.normalize(
          { "alpha", "beta " },
          { " " },
          { separator = " ", trailing_separator_allowed = false }
        )
        assert.same({ "alpha", "beta" }, pieces)
        assert.same({ " " }, gaps)
      end)

      it("works with a newline separator (e.g., YAML block style)", function()
        local pieces, gaps = separator_normalize.normalize(
          { "alpha: 1", "beta: 2" },
          { "" },
          { separator = "\n", trailing_separator_allowed = false }
        )
        assert.same({ "alpha: 1", "beta: 2" }, pieces)
        assert.same({ "\n" }, gaps)
      end)
    end)
  end)
end)
