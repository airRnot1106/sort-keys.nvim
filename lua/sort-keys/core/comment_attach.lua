local M = {}

local function copy_entry(e)
  local out = {}
  for k, v in pairs(e) do
    out[k] = v
  end
  out.range = { e.range[1], e.range[2], e.range[3], e.range[4] }
  return out
end

---@param a integer[]  {row, col}
---@param b integer[]  {row, col}
local function pos_le(a, b)
  if a[1] ~= b[1] then
    return a[1] < b[1]
  end
  return a[2] <= b[2]
end

---Expand `entry.range` to include `range` (range union).
local function absorb(entry, range)
  if range[1] < entry.range[1] or (range[1] == entry.range[1] and range[2] < entry.range[2]) then
    entry.range[1], entry.range[2] = range[1], range[2]
  end
  if range[3] > entry.range[3] or (range[3] == entry.range[3] and range[4] > entry.range[4]) then
    entry.range[3], entry.range[4] = range[3], range[4]
  end
end

---Pick the entry that the comment should be attached to.
---
---Policy:
---  * Same-line trailing — if the immediately preceding entry ends on the
---    same row the comment starts, the comment belongs to that entry.
---  * Otherwise, leading — the comment attaches to the first entry that
---    starts at or after the comment ends.
---  * If there is no following entry, the comment falls back to the
---    preceding entry as a trailing attachment.
local function target_for_comment(comment, entries)
  local c_start = { comment.range[1], comment.range[2] }
  local c_end = { comment.range[3], comment.range[4] }

  local prev, next_entry
  for _, e in ipairs(entries) do
    local e_start = { e.range[1], e.range[2] }
    local e_end = { e.range[3], e.range[4] }
    if pos_le(e_end, c_start) then
      prev = e
    elseif pos_le(c_end, e_start) and not next_entry then
      next_entry = e
    end
  end

  if prev and prev.range[3] == comment.range[1] then
    return prev
  end
  if next_entry then
    return next_entry
  end
  return prev
end

---@param entries table[]   ordered by source position
---@param comments table[]  each has a `range` field
---@return table[]
function M.attach(entries, comments)
  local result = {}
  for i, e in ipairs(entries) do
    result[i] = copy_entry(e)
  end

  for _, c in ipairs(comments) do
    local target = target_for_comment(c, result)
    if target then
      absorb(target, c.range)
    end
  end

  return result
end

return M
