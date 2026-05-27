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

    -- opts.data_lengths lets a piece declare where its "data" portion ends
    -- and an absorbed trailing-comment "suffix" begins. With it, the policy
    -- can splice a missing separator BETWEEN data and suffix instead of
    -- appending it to the piece (which on line-comment languages would
    -- bury the separator inside the comment). Without it the policy keeps
    -- the existing gap-prepend behavior so legacy callers are unaffected.
    describe("with opts.data_lengths (data/suffix-aware splicing)", function()
      it("splices the separator at data_lengths[i] inside the piece", function()
        -- piece[1] = data `"a": 1` + suffix ` // T-a`. data_lengths[1] = 6.
        local pieces, gaps = separator_normalize.normalize(
          { '"a": 1 // T-a', '"b": 2' },
          { "\n  " },
          {
            separator = ",",
            trailing_separator_allowed = false,
            data_lengths = { 6, 6 },
          }
        )
        assert.same({ '"a": 1, // T-a', '"b": 2' }, pieces)
        -- The gap stays clean — the separator went into the piece, not the gap.
        assert.same({ "\n  " }, gaps)
      end)

      it("does not splice when the suffix already starts with the separator", function()
        -- piece[1] data `"a": 1` + suffix `, // T-a` already carries `,`.
        local pieces, gaps = separator_normalize.normalize(
          { '"a": 1, // T-a', '"b": 2' },
          { "\n  " },
          {
            separator = ",",
            trailing_separator_allowed = false,
            data_lengths = { 6, 6 },
          }
        )
        assert.same({ '"a": 1, // T-a', '"b": 2' }, pieces)
        assert.same({ "\n  " }, gaps)
      end)

      it("strips the separator from the suffix's leading position on the last piece", function()
        -- piece[2] = data `"b": 2` + suffix `, // T-b`. last piece, forbid trailing.
        -- Stripping must come from the suffix's front, not from data's tail
        -- (which would do nothing) nor by leaving the suffix untouched (which
        -- would leave a stray separator before the comment).
        local pieces, gaps = separator_normalize.normalize(
          { '"a": 1', '"b": 2, // T-b' },
          { ",\n  " },
          {
            separator = ",",
            trailing_separator_allowed = false,
            data_lengths = { 6, 6 },
          }
        )
        assert.same({ '"a": 1', '"b": 2 // T-b' }, pieces)
        assert.same({ ",\n  " }, gaps)
      end)

      it(
        "keeps the suffix's leading separator on the last piece when the language allows it",
        function()
          local pieces, gaps = separator_normalize.normalize(
            { '"a": 1', '"b": 2, // T-b' },
            { ",\n  " },
            {
              separator = ",",
              trailing_separator_allowed = true,
              data_lengths = { 6, 6 },
            }
          )
          assert.same({ '"a": 1', '"b": 2, // T-b' }, pieces)
          assert.same({ ",\n  " }, gaps)
        end
      )

      it(
        "falls back to data tail when the suffix is empty (data_lengths[i] == #pieces[i])",
        function()
          -- No trailing suffix → the policy should behave like the no-
          -- data_lengths path: trailing-sep strip operates on data's tail.
          local pieces, gaps = separator_normalize.normalize({ '"a": 1', '"b": 2,' }, { ", " }, {
            separator = ",",
            trailing_separator_allowed = false,
            data_lengths = { 6, 7 },
          })
          assert.same({ '"a": 1', '"b": 2' }, pieces)
          assert.same({ ", " }, gaps)
        end
      )

      it("relocates a gap-leading separator into the piece's data/suffix boundary", function()
        -- Reproduces the user-reported case where the entry was
        -- originally last in source (no inline `,`) but absorbed a
        -- trailing `// comment`. After sort it is no longer last; the
        -- gap that follows starts with the `,` carried over from a
        -- different source-position slot. Left as-is it would render
        -- after the comment and be swallowed by the line-comment.
        -- The policy must move that leading `,` into the piece's
        -- data/suffix boundary and strip it from the gap so the
        -- separator lands before the comment.
        local pieces, gaps = separator_normalize.normalize(
          { '"a": 1 // T-a', '"b": 2' },
          { ",\n  " },
          {
            separator = ",",
            trailing_separator_allowed = false,
            data_lengths = { 6, 6 },
          }
        )
        assert.same({ '"a": 1, // T-a', '"b": 2' }, pieces)
        assert.same({ "\n  " }, gaps)
      end)

      it(
        "strips a redundant gap-leading separator when the piece suffix already carries one",
        function()
          -- The entry absorbed `, // hoge` from source: piece's suffix
          -- already starts with `,`, so the slot's separator is correctly
          -- placed. The gap that follows still carries a leading `,`
          -- (a different source-position neighbor's trailing comma).
          -- Left there it would render after the comment and look like a
          -- duplicate "`, // hoge,`". Strip it.
          local pieces, gaps = separator_normalize.normalize(
            { '"a": 1, // T-a', '"b": 2' },
            { ",\n  " },
            {
              separator = ",",
              trailing_separator_allowed = true,
              data_lengths = { 6, 6 },
            }
          )
          assert.same({ '"a": 1, // T-a', '"b": 2' }, pieces)
          assert.same({ "\n  " }, gaps)
        end
      )

      it(
        "appends a trailing separator to the new-last piece when source_last_had_trailing_sep is set and the language allows it",
        function()
          -- opts.source_last_had_trailing_sep is the applier's signal
          -- that the source used trailing-separator style (e.g. JSONC
          -- with `,` after every entry, including the last). Reordering
          -- can move the new-last entry out of that slot, so the policy
          -- adds one back to keep the style consistent.
          local pieces, gaps = separator_normalize.normalize({ '"a": 1', '"b": 2' }, { ",\n  " }, {
            separator = ",",
            trailing_separator_allowed = true,
            data_lengths = { 6, 6 },
            source_last_had_trailing_sep = true,
          })
          assert.same({ '"a": 1', '"b": 2,' }, pieces)
          assert.same({ ",\n  " }, gaps)
        end
      )

      it("leaves the new-last piece alone when source_last_had_trailing_sep is false", function()
        local pieces, gaps = separator_normalize.normalize({ '"a": 1', '"b": 2' }, { ",\n  " }, {
          separator = ",",
          trailing_separator_allowed = true,
          data_lengths = { 6, 6 },
          source_last_had_trailing_sep = false,
        })
        assert.same({ '"a": 1', '"b": 2' }, pieces)
        assert.same({ ",\n  " }, gaps)
      end)
    end)
  end)
end)
