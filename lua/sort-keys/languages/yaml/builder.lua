-- YAML builder. Parallel to json_builder in flow, but YAML's
-- per-container structural separator and per-pair key extraction force a
-- separate handler today: block_mapping_pair / flow_pair have no `key:` /
-- `value:` field syntax (so the builder reads them via named_child rather
-- than via query captures), and block / flow containers want different
-- inter-entry separators on the resulting Outline.

local h = require("sort-keys.core.builder_helpers")
local container_pick = require("sort-keys.core.container_pick")
local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

-- Half-open range overlap; mirrors core/policy.apply_selection_overlay so a
-- visual selection picks the same containers it later marks movable. YAML's
-- indent-based syntax means a full-line `V` selection naturally starts at
-- column 0 and therefore is NOT contained inside an indented inner
-- container, so we test for intersection rather than containment when the
-- target is a selection.
local function ranges_intersect(r1, r2)
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

local function count_entries_overlapping(container, entries, selection_range)
  local n = 0
  for _, e in ipairs(entries) do
    local parent = e.node:parent()
    if parent and h.node_id_key(parent) == container.node_key then
      if ranges_intersect(e.range, selection_range) then
        n = n + 1
      end
    end
  end
  return n
end

-- YAML-specific override of pick_innermost: a visual range that overlaps an
-- indented child also overlaps every single-entry value-level mapping inside
-- that child (e.g. `any: true` inside `vim:`). Those degenerate single-entry
-- containers offer nothing to sort, so we require at least two entries to
-- overlap before considering a container a sortable candidate. The shared
-- h.pick_innermost uses strict containment + 1-entry minimum, which is wrong
-- for YAML's indentation-anchored selections.
local function pick_innermost(containers, entries, target)
  if target.kind == "cursor" then
    return container_pick.for_cursor(containers, target.pos)
  end
  local best, best_area
  for _, c in ipairs(containers) do
    if ranges_intersect(c.range, target.range) then
      if count_entries_overlapping(c, entries, target.range) >= 2 then
        local area = h.range_area(c.range)
        if not best_area or area < best_area then
          best, best_area = c, area
        end
      end
    end
  end
  return best
end

-- ─── YAML anchor / alias detection ────────────────────────────────────────────

-- Any node whose subtree contains a `&name` (anchor) or `*name` (alias) is
-- not safe to reorder past its counterpart. The existing anchored-slot rule
-- in core/policy.lua already pins entries with movable=false in their
-- declared position, so we just propagate that single flag here.
local function subtree_has_anchor_or_alias(node)
  local t = node:type()
  if t == "anchor" or t == "alias" then
    return true
  end
  for child in node:iter_children() do
    if subtree_has_anchor_or_alias(child) then
      return true
    end
  end
  return false
end

-- ─── YAML-specific separator policy per container ─────────────────────────────

-- Block containers carry their separation in the newline + indent of the
-- buffer gap; an inline structural separator would be wrong. Flow containers
-- use `,` and YAML 1.2 forbids a trailing comma on the last entry.
local function separator_for_container(node_type)
  if node_type == "flow_mapping" or node_type == "flow_sequence" then
    return ",", false
  end
  return "", true
end

-- YAML comments are often parented at the stream / document / outer-pair
-- level even when they conceptually decorate the next container's first
-- entry (block_mapping doesn't enclose its leading comment in the AST).
-- We therefore index comments by range proximity: a comment is assigned to
-- the smallest container that either contains it or starts at or after its
-- end. comment_attach then decides leading vs trailing inside that
-- container.
local function range_strictly_before(a_end, b_start)
  if a_end[1] ~= b_start[1] then
    return a_end[1] < b_start[1]
  end
  return a_end[2] <= b_start[2]
end

local function pick_container_for_comment(containers, comment)
  local best, best_area
  -- Phase 1: smallest container that fully contains the comment.
  for _, c in ipairs(containers) do
    if h.contains_range(c.range, comment.range) then
      local area = h.range_area(c.range)
      if not best or area < best_area then
        best = c
        best_area = area
      end
    end
  end
  if best then
    return best
  end
  -- Phase 2: smallest container that starts at or after the comment ends.
  for _, c in ipairs(containers) do
    if
      range_strictly_before({ comment.range[3], comment.range[4] }, { c.range[1], c.range[2] })
    then
      local area = h.range_area(c.range)
      if not best or area < best_area then
        best = c
        best_area = area
      end
    end
  end
  return best
end

local function index_comments_by_container(comments, containers)
  local by_key = {}
  for _, c in ipairs(comments) do
    local picked = pick_container_for_comment(containers, c)
    if picked then
      by_key[picked.node_key] = by_key[picked.node_key] or {}
      by_key[picked.node_key][#by_key[picked.node_key] + 1] = c
    end
  end
  return by_key
end

local function find_container_for_node(containers_by_key, node)
  return containers_by_key[h.node_id_key(node)]
end

-- YAML wraps every value in a flow_node / block_node before reaching the
-- inner container, so a single :named_child(0) hop is normally needed to
-- locate a nested mapping / sequence from the pair's value node.
local function descend_to_container(containers_by_key, node)
  if not node then
    return nil
  end
  local direct = find_container_for_node(containers_by_key, node)
  if direct then
    return direct
  end
  local inner = node:named_child(0)
  if inner then
    return find_container_for_node(containers_by_key, inner)
  end
  return nil
end

-- ─── build_outline ────────────────────────────────────────────────────────────

local function build_outline(container, ctx)
  if not h.capability_allows(container.kind, ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_parent[container.node_key] or {}
  local sorted_raw = h.sort_entries_by_position(raw)

  local outline_entries = {}
  for i, e in ipairs(sorted_raw) do
    local entry = {
      kind = e.entry_kind,
      range = h.clamp_range_to_buffer(ctx.bufnr, e.range),
      movable = not subtree_has_anchor_or_alias(e.node),
      anchor = i,
      attached = {},
      child = nil,
    }

    if e.entry_kind == "pair" then
      local key_node = e.node:named_child(0)
      if not key_node then
        return nil
      end
      local key_text = vim.treesitter.get_node_text(key_node, ctx.bufnr)
      entry.sort_key = key_normalize.yaml(key_text)
      local value_node = e.node:named_child(1)
      if value_node then
        local inner = descend_to_container(ctx.containers_by_key, value_node)
        if inner then
          entry.child = build_outline(inner, ctx)
        end
      end
    else
      local elem_text = vim.treesitter.get_node_text(e.node, ctx.bufnr)
      entry.sort_key = h.normalize_element_text(elem_text)
      local inner = descend_to_container(ctx.containers_by_key, e.node)
      if inner then
        entry.child = build_outline(inner, ctx)
      end
    end

    outline_entries[#outline_entries + 1] = entry
  end

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_parent[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  local sep, trailing = separator_for_container(container.node:type())

  -- A leading sibling comment (e.g., a top-level `# foo` above the first
  -- pair) is absorbed into the first entry by comment_attach and therefore
  -- pulls that entry's range above the container's own start. Extend the
  -- outline range to cover every entry so the applier can compute a valid
  -- prefix / suffix without "start > end" errors.
  local outline_range = h.clamp_range_to_buffer(ctx.bufnr, container.range)
  for _, e in ipairs(outline_entries) do
    local er = e.range
    if er[1] < outline_range[1] or (er[1] == outline_range[1] and er[2] < outline_range[2]) then
      outline_range[1], outline_range[2] = er[1], er[2]
    end
    if er[3] > outline_range[3] or (er[3] == outline_range[3] and er[4] > outline_range[4]) then
      outline_range[3], outline_range[4] = er[3], er[4]
    end
  end

  return {
    kind = container.kind,
    range = outline_range,
    structural_separator = sep,
    trailing_separator_allowed = trailing,
    entries = outline_entries,
  }
end

---@param bufnr integer
---@param target table
---@param config { filetype: string, query_text: string, options: table }
---@return table|nil
function M.build(bufnr, target, config)
  if not h.validate_options(config.options) then
    return nil
  end

  local lang = config.options.parser_lang or config.filetype
  local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not parser_ok or parser == nil then
    return nil
  end
  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse(lang, config.query_text)

  local containers, entries, comments, containers_by_key = h.collect_matches(bufnr, root, query)
  if #containers == 0 then
    return nil
  end

  local chosen = pick_innermost(containers, entries, target)
  if not chosen then
    return nil
  end

  local ctx = {
    bufnr = bufnr,
    options = config.options,
    containers_by_key = containers_by_key,
    entries_by_parent = h.index_by_parent(entries),
    comments_by_parent = index_comments_by_container(comments, containers),
  }

  return build_outline(chosen, ctx)
end

-- The `.yml` extension is a write-style alias for YAML; both filetypes
-- resolve to the same `languages/yaml/config.toml` + `sort-keys.scm` so the
-- yml/yaml relationship lives here with the builder, not in core.
M.filetypes = {
  yaml = "yaml",
  yml = "yaml",
}

return M
