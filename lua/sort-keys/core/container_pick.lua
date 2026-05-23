-- The cursor-side container picker, shared across language builders so the
-- "what does the user mean when they hit :SortKeys here?" question has a
-- single answer regardless of filetype. Three-tier resolution:
--   1. strict containment (innermost wins)
--   2. same-row fallback — `const o = ` cursor on the prefix should still find
--      the `{ ... }` on the same line; leftmost `sc` wins so a single-line
--      nested literal selects the outer over the inner
--   3. row-span fallback — covers the closing-`}` line of a multi-line
--      container where no container *starts* on that row.

local M = {}

local function pos_inside(range, row, col)
  local sr, sc, er, ec = range[1], range[2], range[3], range[4]
  if row < sr or row > er then
    return false
  end
  if row == sr and col < sc then
    return false
  end
  if row == er and col > ec then
    return false
  end
  return true
end

local function range_area(r)
  return (r[3] - r[1]) * 1000000 + (r[4] - r[2])
end

---@param containers table[]  -- each must expose `.range = {sr, sc, er, ec}`
---@param pos { [1]: integer, [2]: integer }
---@return table|nil
function M.for_cursor(containers, pos)
  local row, col = pos[1], pos[2]

  local strict = {}
  for _, c in ipairs(containers) do
    if pos_inside(c.range, row, col) then
      strict[#strict + 1] = c
    end
  end
  if #strict > 0 then
    table.sort(strict, function(a, b)
      return range_area(a.range) < range_area(b.range)
    end)
    return strict[1]
  end

  local starting = {}
  for _, c in ipairs(containers) do
    if c.range[1] == row then
      starting[#starting + 1] = c
    end
  end
  if #starting > 0 then
    table.sort(starting, function(a, b)
      return a.range[2] < b.range[2]
    end)
    return starting[1]
  end

  local spanning = {}
  for _, c in ipairs(containers) do
    if c.range[1] <= row and row <= c.range[3] then
      spanning[#spanning + 1] = c
    end
  end
  if #spanning > 0 then
    table.sort(spanning, function(a, b)
      return range_area(a.range) < range_area(b.range)
    end)
    return spanning[1]
  end

  return nil
end

return M
