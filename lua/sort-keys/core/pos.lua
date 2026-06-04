-- Pure buffer-position / range primitives shared by the parse stage
-- (extract) and the comment folder. Ranges are { srow, scol, erow, ecol },
-- 0-indexed and end-exclusive, matching tree-sitter and nvim_buf_* APIs.
-- Centralizing these keeps the "how do two positions compare" rule in one
-- place instead of re-derived (with subtly different < vs <=) per module.

local M = {}

---Lexicographic (row, col) strictly-before.
function M.lt(ar, ac, br, bc)
  return ar < br or (ar == br and ac < bc)
end

---Whether the position (row, col) lies within range r (inclusive of its edges).
---@param r integer[]
---@param row integer
---@param col integer
---@return boolean
function M.contains(r, row, col)
  if row < r[1] or row > r[3] then
    return false
  end
  if row == r[1] and col < r[2] then
    return false
  end
  if row == r[3] and col > r[4] then
    return false
  end
  return true
end

---Whether r's row span fully contains the [srow, erow] line span.
function M.rows_cover(r, srow, erow)
  return r[1] <= srow and erow <= r[3]
end

---Whether `row` falls within r's row span.
function M.row_in_span(r, row)
  return r[1] <= row and row <= r[3]
end

---Whether r's row span overlaps the [srow, erow] line span at all.
function M.rows_overlap(r, srow, erow)
  return r[1] <= erow and srow <= r[3]
end

return M
