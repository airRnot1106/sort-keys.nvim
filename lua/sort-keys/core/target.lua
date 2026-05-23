-- Cmdline [range] is never consumed here; the dispatcher derives the Target
-- from cursor / visual marks instead.

local M = {}

---@param pos { [1]: integer, [2]: integer }  -- 0-indexed {row, col}
---@return table
function M.from_normal(pos)
  return { kind = "cursor", pos = pos }
end

---@param range { [1]: integer, [2]: integer, [3]: integer, [4]: integer }
---@return table
function M.from_visual(range)
  return { kind = "selection", range = range }
end

return M
