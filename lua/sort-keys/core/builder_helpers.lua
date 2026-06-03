-- Shared treesitter scaffolding for all language builders.
--
-- Every per-language builder used to ship its own copy of ~150 lines of
-- node-range serialization, position/area geometry, query iteration, parent
-- indexing, and option validation. The copies were literally identical for
-- the most part, but two recent optimizations (Rust's O(n) min-pass
-- pick_innermost and the in-collect containers_by_key construction) only
-- landed in one builder — proving the duplication had become a place for
-- drift to hide.
--
-- This module exposes the canonical, most-current versions. Builders import
-- it as `local h = require("sort-keys.core.builder_helpers")` and call
-- `h.collect_matches(...)`, `h.pick_innermost(...)`, etc. Language-specific
-- variations stay in the builder: YAML keeps its own pick_innermost
-- (sortable-candidate threshold), Nix keeps its own collect_matches +
-- container-ancestor indexing (binding_set interpose).

local container_pick = require("sort-keys.core.container_pick")

local M = {}

-- ─── range / node-identity helpers ────────────────────────────────────────────

---@param node userdata  treesitter node
---@return integer[]  {srow, scol, erow, ecol}
function M.node_range(node)
  local sr, sc, er, ec = node:range()
  return { sr, sc, er, ec }
end

---String identity for a node, stable across iter_matches calls. Used to
---group entries / comments by their parent container.
---@param node userdata
---@return string
function M.node_id_key(node)
  local sr, sc, er, ec = node:range()
  return string.format("%s:%d:%d:%d:%d", node:type(), sr, sc, er, ec)
end

-- ─── range geometry ───────────────────────────────────────────────────────────

---@param range integer[]  {srow, scol, erow, ecol}
---@param row integer
---@param col integer
---@return boolean
function M.pos_inside(range, row, col)
  local sr, sc, er, ec = range[1], range[2], range[3], range[4]
  if row < sr or row > er then
    return false
  end
  if row == sr and col < sc then
    return false
  end
  if row == er and col > ec then
    return false
  end
  return true
end

---@param outer integer[]
---@param inner integer[]
---@return boolean
function M.contains_range(outer, inner)
  return M.pos_inside(outer, inner[1], inner[2]) and M.pos_inside(outer, inner[3], inner[4])
end

---Lexicographic "size" of a range, suitable for picking innermost: rows
---dominate columns by a wide margin so a range that spans more rows is
---always "bigger" regardless of column counts.
---@param r integer[]
---@return integer
function M.range_area(r)
  return (r[3] - r[1]) * 1000000 + (r[4] - r[2])
end

-- ─── container picking ────────────────────────────────────────────────────────

---Cursor target → delegate to the shared `container_pick.for_cursor` 3-tier
---rule. Selection target → pick the smallest captured container whose range
---fully covers `target.range`, via a single linear pass (no sort).
---
---Languages that need a different selection-side predicate (YAML requires
---at least two overlapping entries before a container counts as sortable)
---keep their own local pick_innermost and call back into this module for
---`range_area` / `contains_range`.
---@param containers table[]  -- each `{ range = {...}, node_key = ..., kind, node }`
---@param target table        -- `{ kind = "cursor", pos = {row, col} }` or
---                              `{ kind = "selection", range = {...} }`
---@return table|nil
function M.pick_innermost(containers, target)
  if target.kind == "cursor" then
    return container_pick.for_cursor(containers, target.pos)
  end
  local best, best_area = nil, nil
  for _, c in ipairs(containers) do
    if M.contains_range(c.range, target.range) then
      local a = M.range_area(c.range)
      if best_area == nil or a < best_area then
        best, best_area = c, a
      end
    end
  end
  return best
end

-- ─── query traversal ──────────────────────────────────────────────────────────

local DEFAULT_CAPTURES = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  key = "sortkeys.key",
  value = "sortkeys.value",
  comment = "sortkeys.comment",
}

local META = {
  kind = "sortkeys.kind",
  entry_kind = "sortkeys.entry_kind",
}

---Iterate a parsed query, triage matches into containers / entries / comments
---by their `@sortkeys.*` capture names, dedup wildcard-captured entries that
---were also captured as comments (the `(container (_) @sortkeys.entry)`
---pattern admits comment children), and build the `node_id → container` map
---in the same pass.
---
---`captures` is optional; defaults to the `sortkeys.*` namespace every
---language uses today. A new language whose query uses different names can
---override the dict to remap.
---
---@param bufnr integer
---@param root userdata
---@param query userdata
---@param captures? table  -- { container, entry, key, value, comment } capture names
---@return table[] containers, table[] entries, table[] comments, table containers_by_key
function M.collect_matches(bufnr, root, query, captures)
  captures = captures or DEFAULT_CAPTURES

  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local containers = {}
  local entry_candidates = {}
  local comments = {}

  local function first_node(match, capture_name)
    local id = cap_id[capture_name]
    if not id then
      return nil
    end
    local nodes = match[id]
    if not nodes then
      return nil
    end
    return nodes[1]
  end

  for _, match, metadata in query:iter_matches(root, bufnr, 0, -1, { all = true }) do
    local container_node = first_node(match, captures.container)
    if container_node then
      local kind = metadata[META.kind]
      if kind then
        containers[#containers + 1] = {
          node = container_node,
          range = M.node_range(container_node),
          kind = kind,
          node_key = M.node_id_key(container_node),
        }
      end
    end

    local entry_node = first_node(match, captures.entry)
    if entry_node then
      local entry_kind = metadata[META.entry_kind]
      if entry_kind then
        entry_candidates[#entry_candidates + 1] = {
          node = entry_node,
          range = M.node_range(entry_node),
          entry_kind = entry_kind,
          key_node = first_node(match, captures.key),
          value_node = first_node(match, captures.value),
        }
      end
    end

    local comment_node = first_node(match, captures.comment)
    if comment_node then
      comments[#comments + 1] = {
        node = comment_node,
        range = M.node_range(comment_node),
      }
    end
  end

  -- The wildcard `(container (_) @sortkeys.entry)` query pattern captures
  -- comment / attribute children as entries too. Drop any entry whose node
  -- was also captured as a comment, otherwise comment_attach's expansion
  -- could push a real entry past it on the same row and the applier would
  -- crash on an out-of-order inter-entry gap.
  local comment_ids = {}
  for _, c in ipairs(comments) do
    comment_ids[M.node_id_key(c.node)] = true
  end
  local entries = {}
  for _, e in ipairs(entry_candidates) do
    if not comment_ids[M.node_id_key(e.node)] then
      entries[#entries + 1] = e
    end
  end

  local containers_by_key = {}
  for _, c in ipairs(containers) do
    containers_by_key[c.node_key] = c
  end

  return containers, entries, comments, containers_by_key
end

-- ─── parent indexing ──────────────────────────────────────────────────────────

---Group `items` (each `{ node = ..., ... }`) by the node_id_key of their
---direct parent. Used by builders to look up "which entries / comments
---belong to a given container".
---
---Languages whose AST interposes an extra wrapper between container and
---entries (Nix `binding_set`, Toml synthesized root) keep their own
---`index_by_container_ancestor` walker; this is the JSON-shaped default.
---@param items table[]
---@return table<string, table[]>
function M.index_by_parent(items)
  local by_parent = {}
  for _, item in ipairs(items) do
    local parent = item.node:parent()
    if parent then
      local pk = M.node_id_key(parent)
      by_parent[pk] = by_parent[pk] or {}
      by_parent[pk][#by_parent[pk] + 1] = item
    end
  end
  return by_parent
end

-- ─── text & option helpers ────────────────────────────────────────────────────

---Trim leading / trailing whitespace and collapse runs of internal whitespace
---to a single space. Used for surface-text sort_keys (array-like containers).
---@param text string
---@return string
function M.normalize_element_text(text)
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  return (trimmed:gsub("%s+", " "))
end

---Validate that the loaded language `.toml` options carry every capability
---flag the policy / applier pipeline needs. `extras` lets a language pin
---additional language-specific requirements without re-listing the baseline.
---@param options table
---@param extras? string[]
---@return boolean
function M.validate_options(options, extras)
  local required = { "can_sort_object", "can_sort_array", "can_deep", "key_quoting" }
  for _, k in ipairs(required) do
    if options[k] == nil then
      return false
    end
  end
  if extras then
    for _, k in ipairs(extras) do
      if options[k] == nil then
        return false
      end
    end
  end
  return true
end

return M
