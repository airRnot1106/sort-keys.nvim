-- Single forward-compatible entry-copy helper.
--
-- `copy(e)` returns a shallow copy of every key on `e` via `pairs`, so any
-- field present on the input round-trips to the output without the helper
-- having to know its name — the only way to guarantee that future Outline
-- fields cannot be silently dropped at a rebuild site. `copy(e, overrides)`
-- is the "rebuild the entry with field X changed" shape used by
-- policy.apply_selection_overlay (overrides `movable`) and
-- walker.rebuild_entry_with_child (overrides `child`); comment_attach uses
-- the plain form and then deep-copies its own range because it mutates
-- ranges in place via `absorb`.
--
-- Range / data_range / attached / child are NOT deep-copied here. Callers
-- that mutate those in place must clone first; the helper's contract is
-- explicitly shallow so the rebuild call sites stay zero-allocation past
-- the outer table.

local M = {}

---@param e table  -- Outline entry
---@param overrides table?  -- fields to overlay on the shallow copy
---@return table
function M.copy(e, overrides)
  local out = {}
  for k, v in pairs(e) do
    out[k] = v
  end
  if overrides then
    for k, v in pairs(overrides) do
      out[k] = v
    end
  end
  return out
end

return M
