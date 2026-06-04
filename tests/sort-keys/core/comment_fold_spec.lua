local comment_fold = require("sort-keys.core.comment_fold")

local function entry(sr, sc, er, ec)
  return { range = { sr, sc, er, ec } }
end

local function comment(sr, sc, er, ec)
  return { range = { sr, sc, er, ec } }
end

describe("core.comment_fold", function()
  it("returns blocks equal to the data ranges when there are no comments", function()
    local blocks = comment_fold.fold({ entry(1, 2, 1, 8), entry(2, 2, 2, 8) }, {})
    assert.are.same({ 1, 2 }, blocks[1].start)
    assert.are.same({ 1, 8 }, blocks[1].finish)
    assert.are.same({ 2, 2 }, blocks[2].start)
    assert.are.same({ 2, 8 }, blocks[2].finish)
  end)

  it("extends the previous entry's block end for a same-line trailing comment", function()
    -- entry "a" ends at (1,8); the comment on the same row attaches to it.
    local entries = { entry(1, 2, 1, 8), entry(2, 2, 2, 8) }
    local blocks = comment_fold.fold(entries, { comment(1, 10, 1, 22) })
    assert.are.same({ 1, 22 }, blocks[1].finish)
    assert.are.same({ 2, 2 }, blocks[2].start)
  end)

  it("extends the next entry's block start for an own-line leading comment", function()
    -- comment on its own line (row 1) precedes entry "b" (rows 2..).
    local entries = { entry(0, 2, 0, 8), entry(2, 2, 2, 8) }
    local blocks = comment_fold.fold(entries, { comment(1, 2, 1, 14) })
    assert.are.same({ 0, 8 }, blocks[1].finish)
    assert.are.same({ 1, 2 }, blocks[2].start)
  end)

  it(
    "attaches a comment above the first entry to that first entry (pulled out of prefix)",
    function()
      local entries = { entry(2, 2, 2, 13) }
      local blocks = comment_fold.fold(entries, { comment(1, 2, 1, 21) })
      assert.are.same({ 1, 2 }, blocks[1].start)
    end
  )

  it("uses the earliest of several stacked leading comments as the block start", function()
    local entries = { entry(0, 2, 0, 8), entry(3, 2, 3, 8) }
    local blocks = comment_fold.fold(entries, { comment(1, 2, 1, 10), comment(2, 2, 2, 10) })
    assert.are.same({ 1, 2 }, blocks[2].start)
  end)

  it("attaches an own-line comment after the last entry to the last entry's block end", function()
    local entries = { entry(1, 2, 1, 8) }
    local blocks = comment_fold.fold(entries, { comment(2, 2, 2, 16) })
    assert.are.same({ 2, 16 }, blocks[1].finish)
  end)
end)
