local entry_mod = require("sort-keys.core.entry")
local unicode = require("sort-keys.core.unicode")

local M = {}

-- ─── key transformation pipeline ──────────────────────────────────────────
-- Order matters: NFC must run before regex (so the pattern matches normalized
-- text), regex before casefold (so case-sensitive patterns still work), and
-- numeric parsing last so non-numeric input falls back to string compare.

local function casefold(s)
  return s:lower()
end

---@param sort_key string
---@param flags table
---@param normalize_keys boolean
---@return string
local function logical_key(sort_key, flags, normalize_keys)
  local k = sort_key
  if normalize_keys then
    k = unicode.nfc(k)
  end
  if flags.regex then
    local m = string.match(k, flags.regex)
    if m ~= nil then
      k = m
    end
  end
  if flags.ignore_case then
    k = casefold(k)
  end
  return k
end

---@param key string
---@param numeric boolean
---@return number|nil
local function maybe_numeric(key, numeric)
  if not numeric then
    return nil
  end
  return tonumber(key)
end

-- `n` flag requires both sides to tonumber for numeric comparison;
-- if either fails, fall back to string compare.
local function default_compare(a_key, b_key, flags)
  local an = maybe_numeric(a_key, flags.numeric)
  local bn = maybe_numeric(b_key, flags.numeric)
  if flags.numeric and an ~= nil and bn ~= nil then
    return an < bn
  end
  return a_key < b_key
end

-- ─── deduplicate (`u` flag) ───────────────────────────────────────────────
-- "First occurrence" is judged by anchor (declared / source order), not by
-- the entry's position in the input list — entries may already have been
-- shuffled by an earlier movable-slot rearrangement.
local function deduplicate(entries, flags, normalize_keys)
  local seen = {}
  local kept_in_decl_order = {}

  -- Re-sort to declared order so that "first occurrence" wins regardless of
  -- how the caller arranged the entry list before reaching us.
  local by_anchor = {}
  for _, e in ipairs(entries) do
    table.insert(by_anchor, e)
  end
  table.sort(by_anchor, function(a, b)
    return a.anchor < b.anchor
  end)

  for _, e in ipairs(by_anchor) do
    local k = logical_key(e.sort_key, flags, normalize_keys)
    if not seen[k] then
      seen[k] = true
      kept_in_decl_order[#kept_in_decl_order + 1] = e
    end
  end

  local keep = {}
  for _, e in ipairs(kept_in_decl_order) do
    keep[e] = true
  end
  local out = {}
  local dropped = {}
  for _, e in ipairs(entries) do
    if keep[e] then
      out[#out + 1] = e
    else
      dropped[#dropped + 1] = e
    end
  end
  return out, dropped
end

-- ─── stable sort over movable slots only ─────────────────────────────────
-- Non-movable entries keep their relative position among the surviving
-- entries (post-dedup); movable entries are reordered among the remaining
-- slots in sorted order. We re-number slots to the dense post-dedup range
-- 1..#entries by declared (anchor) order so that `u`-removed gaps never
-- drop non-movable entries whose original anchor exceeds #entries.
local function sort_with_anchors(entries, less_fn)
  local by_anchor = {}
  for _, e in ipairs(entries) do
    by_anchor[#by_anchor + 1] = e
  end
  table.sort(by_anchor, function(a, b)
    return a.anchor < b.anchor
  end)

  local dense_slot_of = {}
  for i, e in ipairs(by_anchor) do
    dense_slot_of[e] = i
  end

  local movable_list = {}
  local fixed = {}
  for _, e in ipairs(entries) do
    if e.movable then
      movable_list[#movable_list + 1] = e
    else
      fixed[dense_slot_of[e]] = e
    end
  end

  table.sort(movable_list, function(a, b)
    if less_fn(a, b) then
      return true
    end
    if less_fn(b, a) then
      return false
    end
    return a.anchor < b.anchor
  end)

  local total = #entries
  local out = {}
  local mi = 1
  for slot = 1, total do
    if fixed[slot] then
      out[slot] = fixed[slot]
    else
      out[slot] = movable_list[mi]
      mi = mi + 1
    end
  end
  return out
end

local function shallow_copy_outline(o, entries, dropped)
  return {
    kind = o.kind,
    range = o.range,
    structural_separator = o.structural_separator,
    trailing_separator_allowed = o.trailing_separator_allowed,
    entries = entries,
    -- Entries removed by the `u` flag. The applier needs their ranges to
    -- rebuild the container partition; empty when nothing was deduped.
    dropped = dropped or {},
  }
end

---@param outline table
---@param opts { flags: table, normalize_keys: boolean, comparator: function? }
---@return table  -- new Outline (input is not mutated)
function M.sort(outline, opts)
  local flags = opts.flags
  local normalize_keys = opts.normalize_keys

  local entries = {}
  for _, e in ipairs(outline.entries) do
    entries[#entries + 1] = e
  end

  local dropped = {}
  if flags.unique then
    entries, dropped = deduplicate(entries, flags, normalize_keys)
  end

  -- Pre-compute logical keys so the comparator sees stable, transformed keys.
  local key_cache = {}
  for _, e in ipairs(entries) do
    key_cache[e] = logical_key(e.sort_key, flags, normalize_keys)
  end

  local less
  if opts.comparator then
    local ctx = {
      kind = outline.kind,
      flags = flags,
      entries = entries,
    }
    less = function(a, b)
      return opts.comparator(key_cache[a], key_cache[b], ctx)
    end
  else
    less = function(a, b)
      return default_compare(key_cache[a], key_cache[b], flags)
    end
  end

  if flags.reverse then
    local prev = less
    less = function(a, b)
      return prev(b, a)
    end
  end

  local sorted = sort_with_anchors(entries, less)
  return shallow_copy_outline(outline, sorted, dropped)
end

-- ─── apply_selection_overlay (any-overlap rule) ──────────────────────────

---@param r1 table 4-tuple {srow, scol, erow, ecol}
---@param r2 table 4-tuple
---@return boolean
local function ranges_overlap(r1, r2)
  -- Half-open intervals ([start, end)) are required: column-adjacent ranges
  -- must read as "touching, not overlapping", and Lua's treesitter ranges
  -- are already end-exclusive — switching to closed intervals would mark
  -- every immediate-neighbor entry movable by mistake.
  local s1r, s1c, e1r, e1c = r1[1], r1[2], r1[3], r1[4]
  local s2r, s2c, e2r, e2c = r2[1], r2[2], r2[3], r2[4]

  if e1r < s2r or (e1r == s2r and e1c <= s2c) then
    return false
  end
  if e2r < s1r or (e2r == s1r and e2c <= s1c) then
    return false
  end
  return true
end

---@param outline table
---@param selection_range table
---@return table  -- new Outline; movable flag rewritten by overlap
function M.apply_selection_overlay(outline, selection_range)
  local new_entries = {}
  for _, e in ipairs(outline.entries) do
    -- entry.copy forwards every field present on `e` so any Outline field
    -- survives the overlay without having to be enumerated here. The only
    -- field this overlay touches is `movable`.
    new_entries[#new_entries + 1] = entry_mod.copy(e, {
      movable = ranges_overlap(e.range, selection_range),
    })
  end
  return shallow_copy_outline(outline, new_entries)
end

return M
