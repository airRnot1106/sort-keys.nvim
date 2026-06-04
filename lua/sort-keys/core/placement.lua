-- PLACEMENT axis of the Sort abstraction: map a comparator onto the entry
-- slots while honoring pins and fences. One pure function powers three
-- features that all reduce to "keep some slots fixed, sort the rest":
--   * language pins      (movable = false)            — hold their slot
--   * fences             (movable = false, fence)     — also block crossing
--   * Visual partial sort (entries outside selection flipped to movable=false)
--
-- A plain pin is permeable: movable entries may reorder across it, it just
-- keeps its own slot. A fence is impermeable: movable entries sort only within
-- the segment between fences and never cross one.

local M = {}

---Stable sort in place using a 3-way comparator, breaking ties by the item's
---original index so equal keys keep source order.
---@param list table[]
---@param compare fun(a: table, b: table): integer
local function stable_sort(list, compare)
  local indexed = {}
  for i, v in ipairs(list) do
    indexed[i] = { value = v, index = i }
  end
  table.sort(indexed, function(x, y)
    local c = compare(x.value, y.value)
    if c ~= 0 then
      return c < 0
    end
    return x.index < y.index
  end)
  for i, t in ipairs(indexed) do
    list[i] = t.value
  end
end

---Reorder `entries` (source order) under `compare`, pinning non-movable
---entries to their slot and never letting movable entries cross a fence.
---@param entries table[]
---@param compare fun(a: table, b: table): integer
---@return table[]
function M.arrange(entries, compare)
  local n = #entries

  -- Segment id for a source position = number of fences strictly before it.
  -- Movable entries and free slots in the same segment sort among themselves.
  local fence_positions = {}
  for pos, entry in ipairs(entries) do
    if entry.movable == false and entry.fence then
      fence_positions[#fence_positions + 1] = pos
    end
  end
  local function segment_of(pos)
    local seg = 0
    for _, fpos in ipairs(fence_positions) do
      if fpos < pos then
        seg = seg + 1
      end
    end
    return seg
  end

  local result = {}
  local free_slots = {}
  local movables_by_segment = {}
  for pos, entry in ipairs(entries) do
    if entry.movable == false then
      result[pos] = entry
    else
      free_slots[#free_slots + 1] = pos
      local seg = segment_of(pos)
      movables_by_segment[seg] = movables_by_segment[seg] or {}
      table.insert(movables_by_segment[seg], entry)
    end
  end

  for _, list in pairs(movables_by_segment) do
    stable_sort(list, compare)
  end

  local cursor_by_segment = {}
  for _, pos in ipairs(free_slots) do
    local seg = segment_of(pos)
    cursor_by_segment[seg] = (cursor_by_segment[seg] or 0) + 1
    result[pos] = movables_by_segment[seg][cursor_by_segment[seg]]
  end

  -- Rebuild as a dense array 1..n (result is keyed by position but complete).
  local dense = {}
  for pos = 1, n do
    dense[pos] = result[pos]
  end
  return dense
end

return M
