-- Single forward-compatible entry-copy helper. Replaces three previously
-- divergent implementations that all manually enumerated Outline-entry
-- field names — a pattern that silently dropped any field added later
-- (most recently `data_range`, which had to be patched twice before
-- becoming the motivation for this module).
--
-- `copy(e)` returns a shallow copy of every key on `e` via `pairs`, so a
-- new field appears in the output the same iteration it appears in the
-- input. `copy(e, overrides)` is the "rebuild the entry with field X
-- changed" shape used by policy.apply_selection_overlay (overrides
-- `movable`) and walker.rebuild_entry_with_child (overrides `child`);
-- comment_attach uses the plain form and then deep-copies its own range
-- because it mutates ranges in place via `absorb`.
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
