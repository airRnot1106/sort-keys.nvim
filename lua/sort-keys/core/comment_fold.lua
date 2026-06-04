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

local pos = require("sort-keys.core.pos")

local M = {}

local pos_lt = pos.lt

---@param entries table[]   -- each { range = { sr, sc, er, ec } }, source order
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
  if #entries == 0 then
    return blocks
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
    -- row, with data end at or before the comment start. Closest such entry.
    local tail_idx
    for i, e in ipairs(entries) do
      local er = e.range
      if er[3] == c_srow and not pos_lt(c_srow, c_scol, er[3], er[4]) then
        if
          tail_idx == nil
          or pos_lt(entries[tail_idx].range[3], entries[tail_idx].range[4], er[3], er[4])
        then
          tail_idx = i
        end
      end
    end

    if tail_idx then
      extend_finish(tail_idx, c_erow, c_ecol)
    else
      -- otherwise it is an own-line comment: attach to the first entry whose
      -- data starts at or after the comment, as that entry's lead.
      local lead_idx
      for i, e in ipairs(entries) do
        local er = e.range
        if not pos_lt(er[1], er[2], c_erow, c_ecol) then
          lead_idx = i
          break
        end
      end
      if lead_idx then
        extend_start(lead_idx, c_srow, c_scol)
      else
        -- no following entry: an own-line comment after the last entry.
        extend_finish(#entries, c_erow, c_ecol)
      end
    end
  end

  return blocks
end

return M
