-- TRAVERSAL axis of the Sort abstraction: decide *where* in the IR tree the
-- per-container sort runs. `shallow` sorts only the chosen container;
-- `deep` recurses post-order (children before their parent) so a sorted child
-- is already in place when the parent reorders. The sort function itself is
-- oblivious to recursion — it only ever sees one container.

local ir = require("sort-keys.core.ir")
local render = require("sort-keys.core.render")

local M = {}

---@param container table
---@param sortfn fun(c: table): table
---@return table
function M.shallow(container, sortfn)
  return sortfn(container)
end

---@param container table
---@param sortfn fun(c: table): table
---@return table
function M.deep(container, sortfn)
  local new_entries = {}
  for i, entry in ipairs(container.entries) do
    if entry.child then
      local sorted_child = M.deep(entry.child, sortfn)
      local overrides = { child = sorted_child }
      -- A value_keyed entry (an array element) sorts by its OWN content, not a
      -- separate key. Deep sort rewrites that content, so the ordering key must
      -- be re-derived from the sorted child here; both this pass and a later
      -- re-extracted pass then order the array by the same sorted form, which
      -- is what makes deep sort idempotent over an array of containers.
      if entry.value_keyed then
        overrides.sort_key = (entry.pre or "") .. render.render(sorted_child) .. (entry.post or "")
      end
      new_entries[i] = ir.copy_entry(entry, overrides)
    else
      new_entries[i] = entry
    end
  end
  return sortfn(ir.copy_container(container, { entries = new_entries }))
end

return M
