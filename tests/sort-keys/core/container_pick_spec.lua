describe("sort-keys.core.container_pick", function()
  local pick
  local function c(range)
    return { range = range }
  end

  before_each(function()
    package.loaded["sort-keys.core.container_pick"] = nil
    pick = require("sort-keys.core.container_pick")
  end)

  describe("for_cursor — strict containment", function()
    it("picks the only container that strictly contains the cursor", function()
      local outer = c({ 0, 10, 0, 30 })
      assert.equals(outer, pick.for_cursor({ outer }, { 0, 15 }))
    end)

    it("picks the innermost (smallest area) when several contain the cursor", function()
      local outer = c({ 0, 0, 5, 0 })
      local inner = c({ 1, 2, 3, 4 })
      assert.equals(inner, pick.for_cursor({ outer, inner }, { 2, 0 }))
    end)

    it("treats cursor on the closing bracket column as inside (col == ec)", function()
      -- ec is end-exclusive in Outline terms but pos_inside accepts col == ec
      -- on the end row because that is the byte the bracket occupies.
      local cont = c({ 0, 10, 0, 30 })
      assert.equals(cont, pick.for_cursor({ cont }, { 0, 30 }))
    end)
  end)

  describe("for_cursor — same-row fallback", function()
    it(
      "picks a single-line container that starts on the cursor's row even when cursor is left of the opening bracket",
      function()
        -- Mirrors the `const o = { ... };` case: cursor sits on the `const o =`
        -- prefix, container starts at the `{` further right on the same line.
        local cont = c({ 0, 10, 0, 30 })
        assert.equals(cont, pick.for_cursor({ cont }, { 0, 5 }))
      end
    )

    it(
      "picks a multi-line container that starts on the cursor's row when cursor is left of the opening bracket",
      function()
        local cont = c({ 0, 10, 3, 1 })
        assert.equals(cont, pick.for_cursor({ cont }, { 0, 5 }))
      end
    )

    it("prefers the leftmost starting container when several start on the cursor's row", function()
      -- Nested object on a single line: `const o = { b: { x: 1 } };`.
      -- Cursor on `const o = ` should land on the OUTER, not the inner.
      local outer = c({ 0, 10, 0, 26 })
      local inner = c({ 0, 16, 0, 22 })
      assert.equals(outer, pick.for_cursor({ outer, inner }, { 0, 5 }))
    end)

    it(
      "picks the leftmost container that starts on the cursor's row, even when a sibling literal exists later on that row",
      function()
        -- Cursor at column 0 on a row that has two sibling literals starting on
        -- it; the leftmost (closer in reading order) wins.
        local first = c({ 2, 10, 2, 12 })
        local second = c({ 2, 20, 2, 30 })
        assert.equals(first, pick.for_cursor({ first, second }, { 2, 0 }))
      end
    )
  end)

  describe("for_cursor — row-span fallback", function()
    it(
      "picks a multi-line container that spans the cursor's row when no container starts on it",
      function()
        -- Cursor sits on the line that ONLY contains the closing brace, so no
        -- container starts on this row; the outer container does span it.
        local outer = c({ 0, 10, 2, 1 })
        assert.equals(outer, pick.for_cursor({ outer }, { 2, 5 }))
      end
    )

    it("returns nil when the cursor is on a row outside every container", function()
      local cont = c({ 0, 10, 1, 1 })
      assert.is_nil(pick.for_cursor({ cont }, { 5, 0 }))
    end)

    it("returns nil when there are no containers at all", function()
      assert.is_nil(pick.for_cursor({}, { 0, 0 }))
    end)
  end)
end)
