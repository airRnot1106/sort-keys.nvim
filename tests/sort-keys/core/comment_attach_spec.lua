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
  end)
end)
