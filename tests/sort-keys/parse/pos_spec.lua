local pos = require("sort-keys.parse.pos")

describe("core.pos", function()
  it("lt is lexicographic on (row, col)", function()
    assert.is_true(pos.lt(1, 5, 2, 0))
    assert.is_true(pos.lt(1, 2, 1, 3))
    assert.is_false(pos.lt(1, 3, 1, 3))
    assert.is_false(pos.lt(2, 0, 1, 9))
  end)

  it("contains treats range edges as inclusive", function()
    local r = { 1, 2, 3, 4 }
    assert.is_true(pos.contains(r, 2, 0))
    assert.is_true(pos.contains(r, 1, 2)) -- on the start edge
    assert.is_true(pos.contains(r, 3, 4)) -- on the end edge
    assert.is_false(pos.contains(r, 1, 1)) -- before start col on start row
    assert.is_false(pos.contains(r, 3, 5)) -- past end col on end row
    assert.is_false(pos.contains(r, 0, 9))
  end)

  it("rows_cover requires the line span to sit inside r's rows", function()
    local r = { 0, 0, 4, 1 }
    assert.is_true(pos.rows_cover(r, 1, 3))
    assert.is_true(pos.rows_cover(r, 0, 4))
    assert.is_false(pos.rows_cover(r, 0, 5)) -- ends past r
    assert.is_false(pos.rows_cover(r, -1, 2))
  end)

  it("row_in_span checks a single row against r's rows", function()
    local r = { 2, 0, 5, 0 }
    assert.is_true(pos.row_in_span(r, 2))
    assert.is_true(pos.row_in_span(r, 5))
    assert.is_false(pos.row_in_span(r, 1))
    assert.is_false(pos.row_in_span(r, 6))
  end)

  it("rows_overlap is true when the row spans touch at all", function()
    local r = { 2, 0, 4, 0 }
    assert.is_true(pos.rows_overlap(r, 4, 9)) -- touch at row 4
    assert.is_true(pos.rows_overlap(r, 0, 2))
    assert.is_false(pos.rows_overlap(r, 5, 9))
    assert.is_false(pos.rows_overlap(r, 0, 1))
  end)
end)
