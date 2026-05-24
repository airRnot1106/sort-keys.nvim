-- Pure-policy spec for comment-to-entry attachment.
--
-- The policy operates on plain tables (no treesitter, no buffer) so that the
-- attachment rules can be exhaustively pinned without spinning up a parser.
-- The detail layer (jsonc builder) is responsible for handing this module
-- entries + comments in source order; the module's job is to decide which
-- entry each comment belongs to and to expand that entry's range to swallow
-- the comment.

local function entry(range)
  return {
    kind = "pair",
    sort_key = "k",
    range = range,
    movable = true,
    anchor = 1,
    attached = {},
  }
end

local function comment(range, kind)
  return { range = range, kind = kind or "line" }
end

describe("sort-keys.core.comment_attach", function()
  local comment_attach

  before_each(function()
    package.loaded["sort-keys.core.comment_attach"] = nil
    comment_attach = require("sort-keys.core.comment_attach")
  end)

  describe("attach(entries, comments)", function()
    it("returns entries unchanged when no comments are provided", function()
      local entries = { entry({ 1, 2, 1, 8 }) }
      local result = comment_attach.attach(entries, {})
      assert.same({ 1, 2, 1, 8 }, result[1].range)
    end)

    it("attaches a leading comment to the following entry by expanding its range", function()
      local entries = { entry({ 2, 2, 2, 8 }) }
      local comments = { comment({ 1, 2, 1, 9 }) }
      local result = comment_attach.attach(entries, comments)
      assert.same({ 1, 2, 2, 8 }, result[1].range)
    end)

    it("attaches a same-line trailing comment to the preceding entry", function()
      local entries = { entry({ 1, 2, 1, 8 }) }
      local comments = { comment({ 1, 10, 1, 21 }, "block") }
      local result = comment_attach.attach(entries, comments)
      assert.same({ 1, 2, 1, 21 }, result[1].range)
    end)

    it("attaches a comment between two entries on its own line to the next entry", function()
      local entries = { entry({ 1, 2, 1, 8 }), entry({ 3, 2, 3, 8 }) }
      local comments = { comment({ 2, 2, 2, 9 }) }
      local result = comment_attach.attach(entries, comments)
      assert.same({ 1, 2, 1, 8 }, result[1].range)
      assert.same({ 2, 2, 3, 8 }, result[2].range)
    end)

    it("attaches a comment after the last entry to the preceding entry", function()
      local entries = { entry({ 1, 2, 1, 8 }) }
      local comments = { comment({ 2, 2, 2, 9 }) }
      local result = comment_attach.attach(entries, comments)
      assert.same({ 1, 2, 2, 9 }, result[1].range)
    end)

    it("stacks multiple leading comments onto the next entry", function()
      local entries = { entry({ 3, 2, 3, 8 }) }
      local comments = {
        comment({ 1, 2, 1, 9 }),
        comment({ 2, 2, 2, 9 }),
      }
      local result = comment_attach.attach(entries, comments)
      assert.same({ 1, 2, 3, 8 }, result[1].range)
    end)

    it("handles same-line trailing AND leading-for-next together", function()
      local entries = { entry({ 1, 2, 1, 8 }), entry({ 3, 2, 3, 8 }) }
      local comments = {
        comment({ 1, 10, 1, 21 }, "block"),
        comment({ 2, 2, 2, 9 }),
      }
      local result = comment_attach.attach(entries, comments)
      assert.same({ 1, 2, 1, 21 }, result[1].range)
      assert.same({ 2, 2, 3, 8 }, result[2].range)
    end)

    it("does not mutate the input entries' ranges", function()
      local input_range = { 2, 2, 2, 8 }
      local entries = { entry(input_range) }
      local comments = { comment({ 1, 2, 1, 9 }) }
      comment_attach.attach(entries, comments)
      assert.same({ 2, 2, 2, 8 }, entries[1].range)
      assert.same({ 2, 2, 2, 8 }, input_range)
    end)

    it(
      "routes the second leading-block comment to the same next entry as the first, not to the previous entry",
      function()
        -- Regression: when entry A absorbs the first leading comment its
        -- expanded range[3] reaches into the rows of the second comment.
        -- Walking the expanded range to pick `prev/next` for the second
        -- comment then loses the "next" candidate (its start row is now ≤
        -- the second comment's start row) and the comment falls back to the
        -- previous entry, producing overlapping entry ranges that crash the
        -- applier with `'start' is higher than 'end'`. The fix: pick prev/
        -- next based on each entry's ORIGINAL range, not the in-progress
        -- expanded one.
        local entries = {
          entry({ 0, 0, 0, 5 }), -- A: prev entry, far above
          entry({ 10, 0, 10, 5 }), -- B: target for both leading blocks
        }
        local comments = {
          comment({ 2, 0, 2, 10 }),
          comment({ 3, 0, 3, 10 }),
          comment({ 6, 0, 6, 10 }),
          comment({ 7, 0, 7, 10 }),
        }
        local result = comment_attach.attach(entries, comments)
        -- A keeps its original range (no comment attaches to it).
        assert.same({ 0, 0, 0, 5 }, result[1].range)
        -- B absorbs all four leading comments; its range start reaches up
        -- to row 2 (the earliest comment) and end stays at row 10.
        assert.same({ 2, 0, 10, 5 }, result[2].range)
      end
    )

    it(
      "keeps non-overlapping entry ranges when two adjacent entries each have a leading-comment block",
      function()
        -- Regression: previously the second comment block (rows 6-7) below
        -- the entry-B fell back to entry B (the previous entry) because B
        -- had already absorbed rows 2-3 and its range[3] grew past row 6.
        -- The correct routing is "B absorbs 2-3, C absorbs 6-7", and after
        -- the fix B's range must not extend into C's row span.
        local entries = {
          entry({ 4, 0, 4, 5 }), -- B
          entry({ 8, 0, 8, 5 }), -- C
        }
        local comments = {
          comment({ 2, 0, 2, 10 }), -- leading for B
          comment({ 3, 0, 3, 10 }), -- leading for B
          comment({ 6, 0, 6, 10 }), -- leading for C
          comment({ 7, 0, 7, 10 }), -- leading for C
        }
        local result = comment_attach.attach(entries, comments)
        assert.same({ 2, 0, 4, 5 }, result[1].range)
        assert.same({ 6, 0, 8, 5 }, result[2].range)
        -- Critical: ranges must not overlap, otherwise applier crashes.
        assert.is_true(result[1].range[3] < result[2].range[1])
      end
    )
  end)
end)
