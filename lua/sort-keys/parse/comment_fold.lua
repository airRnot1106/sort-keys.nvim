-- A parse-stage pure helper (CORE, but used only by extract, never by the
-- transform spine). Given the data-entry ranges and the comment ranges of one
-- container, it decides which entry each comment belongs to and returns an
-- expanded "block" range per entry that swallows its attached comments:
--
--   * a same-line trailing comment   -> extends the previous entry's block end
--                                        (becomes that entry's `tail`)
--   * an own-line (leading) comment   -> extends the next entry's block start
--                                        (becomes that entry's `lead`)
--   * a comment after the last entry  -> extends the last entry's block end
--
-- It is purely range arithmetic (0-indexed, end-exclusive), so it is tested on
-- literals without nvim. extract then slices lead/text/tail bytes from these
-- block boundaries; the separator that sits between an entry's data and its
-- trailing comment stays slot-bound (extract strips it back out), so the sort
-- and render layers never see comments as anything but `lead`/`tail` strings.

local pos = require("sort-keys.parse.pos")

local M = {}

local pos_lt = pos.lt

---@param entries table[]   -- each { range = { sr, sc, er, ec } }, source order
---                          -- (ascending by start position; extract sorts them)
---@param comments table[]  -- each { range = { sr, sc, er, ec } }
---@return table[]          -- parallel to entries: { start = {row,col}, finish = {row,col} }
function M.fold(entries, comments)
  local blocks = {}
  for i, e in ipairs(entries) do
    blocks[i] = {
      start = { e.range[1], e.range[2] },
      finish = { e.range[3], e.range[4] },
    }
  end
  local n = #entries
  if n == 0 or #comments == 0 then
    return blocks
  end

  -- Index the entries once so each comment resolves its entry by binary search;
  -- a per-comment scan over the entries would make a large, heavily commented
  -- container cost O(entries * comments).
  -- ends_on_row[row] = { {end_col, entry_idx}, ... } ascending by end_col; ties
  -- keep the earlier entry LAST so the rightmost-match search below picks it,
  -- matching the scan rule "replace the candidate only on a strictly later end".
  local ends_on_row = {}
  for i, e in ipairs(entries) do
    local er = e.range
    local list = ends_on_row[er[3]]
    if not list then
      list = {}
      ends_on_row[er[3]] = list
    end
    list[#list + 1] = { er[4], i }
  end
  for _, list in pairs(ends_on_row) do
    -- One entry per row is the overwhelmingly common shape; sorting only the
    -- multi-entry rows avoids a per-row table.sort call.
    if #list > 1 then
      table.sort(list, function(a, b)
        if a[1] ~= b[1] then
          return a[1] < b[1]
        end
        return a[2] > b[2]
      end)
    end
  end

  -- First entry whose data starts at or after (row, col): lower bound over the
  -- ascending entry starts.
  local function first_starting_at_or_after(row, col)
    local lo, hi = 1, n + 1
    while lo < hi do
      local mid = math.floor((lo + hi) / 2)
      local er = entries[mid].range
      if pos_lt(er[1], er[2], row, col) then
        lo = mid + 1
      else
        hi = mid
      end
    end
    if lo <= n then
      return lo
    end
    return nil
  end

  local function extend_start(idx, row, col)
    local b = blocks[idx]
    if pos_lt(row, col, b.start[1], b.start[2]) then
      b.start = { row, col }
    end
  end
  local function extend_finish(idx, row, col)
    local b = blocks[idx]
    if pos_lt(b.finish[1], b.finish[2], row, col) then
      b.finish = { row, col }
    end
  end

  for _, c in ipairs(comments) do
    local cr = c.range
    local c_srow, c_scol, c_erow, c_ecol = cr[1], cr[2], cr[3], cr[4]

    -- same-line trailing: the entry whose data ends on this comment's start
    -- row, with data end at or before the comment start. Closest such entry =
    -- rightmost indexed end_col <= the comment's start col.
    local tail_idx
    local row_ends = ends_on_row[c_srow]
    if row_ends then
      local lo, hi = 1, #row_ends + 1
      while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if row_ends[mid][1] <= c_scol then
          lo = mid + 1
        else
          hi = mid
        end
      end
      if lo > 1 then
        tail_idx = row_ends[lo - 1][2]
      end
    end

    if tail_idx then
      extend_finish(tail_idx, c_erow, c_ecol)
    else
      -- otherwise it is an own-line comment: attach to the first entry whose
      -- data starts at or after the comment, as that entry's lead.
      local lead_idx = first_starting_at_or_after(c_erow, c_ecol)
      if lead_idx then
        extend_start(lead_idx, c_srow, c_scol)
      end
      -- An own-line comment after the LAST entry is left unattached: it stays in
      -- the container's suffix (positional) rather than being dragged along when
      -- the last entry moves. Attaching it would, for a container whose node
      -- spans to the next sibling (a TOML [table] section, a YAML document),
      -- corrupt the file by pulling a section/EOF comment into the middle.
    end
  end

  return blocks
end

return M
