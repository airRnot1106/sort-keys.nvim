-- Deep sort recurses post-order: children must be sorted before their parent
-- so that the parent's comparator sees stable, already-sorted child text.

local entry_mod = require("sort-keys.core.entry")
local policy = require("sort-keys.core.policy")

local M = {}

local function rebuild_entry_with_child(entry, sorted_child)
  -- entry.copy forwards every field on `entry` via pairs(), so data_range
  -- (and any future Outline field) survives the deep-sort rebuild without
  -- having to be remembered here. Without it, an entry that comment_attach
  -- expanded to swallow a trailing comment would lose its pre-absorb
  -- boundary the moment :DeepSortKeys recursed over it.
  return entry_mod.copy(entry, { child = sorted_child })
end

local function recurse_children(outline, opts)
  local new_entries = {}
  for _, e in ipairs(outline.entries) do
    if e.child then
      new_entries[#new_entries + 1] = rebuild_entry_with_child(e, M.walk(e.child, opts))
    else
      new_entries[#new_entries + 1] = e
    end
  end
  return {
    kind = outline.kind,
    range = outline.range,
    structural_separator = outline.structural_separator,
    trailing_separator_allowed = outline.trailing_separator_allowed,
    entries = new_entries,
  }
end

---@param outline table
---@param opts { deep: boolean, flags: table, normalize_keys: boolean, comparator: function? }
---@return table
function M.walk(outline, opts)
  local current = opts.deep and recurse_children(outline, opts) or outline
  return policy.sort(current, opts)
end

return M
