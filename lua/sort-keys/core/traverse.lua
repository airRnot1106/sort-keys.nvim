-- TRAVERSAL axis of the Sort abstraction: decide *where* in the IR tree the
-- per-container sort runs. `shallow` sorts only the chosen container;
-- `deep` recurses post-order (children before their parent) so a sorted child
-- is already in place when the parent reorders. The sort function itself is
-- oblivious to recursion — it only ever sees one container.

local ir = require("sort-keys.core.ir")

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
      new_entries[i] = ir.copy_entry(entry, { child = M.deep(entry.child, sortfn) })
    else
      new_entries[i] = entry
    end
  end
  return sortfn(ir.copy_container(container, { entries = new_entries }))
end

return M
