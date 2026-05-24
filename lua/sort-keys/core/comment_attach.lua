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
---
---Selection walks the *original* entry ranges (captured before any absorb
---runs). Walking the in-progress expanded ranges instead breaks when a
---later comment block sits between two entries whose former neighbor has
---already swelled past it — the would-be `next` candidate looks like it
---starts before the comment, so it gets skipped and the comment falls back
---to `prev`, causing entry ranges to overlap.
local function target_index_for_comment(comment, original_ranges)
  local c_start = { comment.range[1], comment.range[2] }
  local c_end = { comment.range[3], comment.range[4] }

  local prev_idx, next_idx
  for i, r in ipairs(original_ranges) do
    local e_start = { r[1], r[2] }
    local e_end = { r[3], r[4] }
    if pos_le(e_end, c_start) then
      prev_idx = i
    elseif pos_le(c_end, e_start) and not next_idx then
      next_idx = i
    end
  end

  if prev_idx and original_ranges[prev_idx][3] == comment.range[1] then
    return prev_idx
  end
  if next_idx then
    return next_idx
  end
  return prev_idx
end

---@param entries table[]   ordered by source position
---@param comments table[]  each has a `range` field
---@return table[]
function M.attach(entries, comments)
  local result = {}
  local original_ranges = {}
  for i, e in ipairs(entries) do
    result[i] = copy_entry(e)
    original_ranges[i] = { e.range[1], e.range[2], e.range[3], e.range[4] }
  end

  for _, c in ipairs(comments) do
    local idx = target_index_for_comment(c, original_ranges)
    if idx then
      absorb(result[idx], c.range)
    end
  end

  return result
end

return M
