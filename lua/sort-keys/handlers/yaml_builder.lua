-- YAML builder. Parallel to json_builder in flow, but YAML's
-- per-container structural separator and per-pair key extraction force a
-- separate handler today: block_mapping_pair / flow_pair have no `key:` /
-- `value:` field syntax (so the builder reads them via named_child rather
-- than via query captures), and block / flow containers want different
-- inter-entry separators on the resulting Outline.

local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")
local container_pick = require("sort-keys.core.container_pick")

local M = {}

local CAPTURE = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  comment = "sortkeys.comment",
}

local META = {
  kind = "sortkeys.kind",
  entry_kind = "sortkeys.entry_kind",
}

-- ─── range / node helpers (duplicated from json_builder; extract on the next handler) ──

local function node_range(node)
  local sr, sc, er, ec = node:range()
  return { sr, sc, er, ec }
end

local function node_id_key(node)
  local sr, sc, er, ec = node:range()
  return string.format("%s:%d:%d:%d:%d", node:type(), sr, sc, er, ec)
end

local function pos_inside(range, row, col)
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

local function contains_range(outer, inner)
  return pos_inside(outer, inner[1], inner[2]) and pos_inside(outer, inner[3], inner[4])
end

local function range_area(r)
  return (r[3] - r[1]) * 1000000 + (r[4] - r[2])
end

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
    if parent and node_id_key(parent) == container.node_key then
      if ranges_intersect(e.range, selection_range) then
        n = n + 1
      end
    end
  end
  return n
end

local function pick_innermost(containers, entries, target)
  if target.kind == "cursor" then
    return container_pick.for_cursor(containers, target.pos)
  end
  -- A visual range that overlaps an indented child also overlaps every
  -- single-entry value-level mapping inside that child (e.g. `any: true`
  -- inside `vim:` in a typical config file). Those degenerate single-entry
  -- containers offer nothing to sort, so we require at least two entries to
  -- overlap before considering a container a sortable candidate.
  local candidates = {}
  for _, c in ipairs(containers) do
    if ranges_intersect(c.range, target.range) then
      if count_entries_overlapping(c, entries, target.range) >= 2 then
        candidates[#candidates + 1] = c
      end
    end
  end
  if #candidates == 0 then
    return nil
  end
  table.sort(candidates, function(a, b)
    return range_area(a.range) < range_area(b.range)
  end)
  return candidates[1]
end

local function normalize_element_text(text)
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  return (trimmed:gsub("%s+", " "))
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

-- ─── query traversal ──────────────────────────────────────────────────────────

local function collect_matches(bufnr, root, query)
  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local containers = {}
  local entries = {}
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
    local container_node = first_node(match, CAPTURE.container)
    if container_node then
      local kind = metadata[META.kind]
      if kind then
        containers[#containers + 1] = {
          node = container_node,
          range = node_range(container_node),
          kind = kind,
          node_key = node_id_key(container_node),
        }
      end
    end

    local entry_node = first_node(match, CAPTURE.entry)
    if entry_node then
      local entry_kind = metadata[META.entry_kind]
      if entry_kind then
        entries[#entries + 1] = {
          node = entry_node,
          range = node_range(entry_node),
          entry_kind = entry_kind,
        }
      end
    end

    local comment_node = first_node(match, CAPTURE.comment)
    if comment_node then
      comments[#comments + 1] = {
        node = comment_node,
        range = node_range(comment_node),
      }
    end
  end

  return containers, entries, comments
end

local function index_by_parent(items)
  local by_parent = {}
  for _, item in ipairs(items) do
    local parent = item.node:parent()
    if parent then
      local pk = node_id_key(parent)
      by_parent[pk] = by_parent[pk] or {}
      by_parent[pk][#by_parent[pk] + 1] = item
    end
  end
  return by_parent
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
    if contains_range(c.range, comment.range) then
      local area = range_area(c.range)
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
      local area = range_area(c.range)
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
  return containers_by_key[node_id_key(node)]
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

-- tree-sitter-yaml routinely reports container ranges that extend one row
-- past the buffer's last actual line (a phantom trailing newline the grammar
-- assumes is there). The applier feeds outline.range straight to
-- `nvim_buf_get_text`, which errors on those out-of-bounds rows, so we clamp
-- the range to the buffer extent before returning.
local function clamp_range_to_buffer(bufnr, range)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local sr, sc, er, ec = range[1], range[2], range[3], range[4]
  if er > line_count - 1 then
    er = line_count - 1
    local last_line = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or ""
    ec = #last_line
  else
    local row_line = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or ""
    if ec > #row_line then
      ec = #row_line
    end
  end
  return { sr, sc, er, ec }
end

-- ─── capability + build_outline ───────────────────────────────────────────────

local function capability_allows(kind, options)
  if kind == "object" then
    return options.can_sort_object == true
  end
  if kind == "array" then
    return options.can_sort_array == true
  end
  return false
end

local function build_outline(container, ctx)
  if not capability_allows(container.kind, ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_parent[container.node_key] or {}
  local sorted_raw = {}
  for _, e in ipairs(raw) do
    sorted_raw[#sorted_raw + 1] = e
  end
  table.sort(sorted_raw, function(a, b)
    if a.range[1] ~= b.range[1] then
      return a.range[1] < b.range[1]
    end
    return a.range[2] < b.range[2]
  end)

  local outline_entries = {}
  for i, e in ipairs(sorted_raw) do
    local entry = {
      kind = e.entry_kind,
      range = clamp_range_to_buffer(ctx.bufnr, e.range),
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
      entry.sort_key = normalize_element_text(elem_text)
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
  local outline_range = clamp_range_to_buffer(ctx.bufnr, container.range)
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

local function validate_options(options)
  local required = {
    "can_sort_object",
    "can_sort_array",
    "can_deep",
    "key_quoting",
  }
  for _, k in ipairs(required) do
    if options[k] == nil then
      return false
    end
  end
  return true
end

---@param bufnr integer
---@param target table
---@param config { filetype: string, query_text: string, options: table }
---@return table|nil
function M.build(bufnr, target, config)
  if not validate_options(config.options) then
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

  local containers, entries, comments = collect_matches(bufnr, root, query)
  if #containers == 0 then
    return nil
  end

  local chosen = pick_innermost(containers, entries, target)
  if not chosen then
    return nil
  end

  local containers_by_key = {}
  for _, c in ipairs(containers) do
    containers_by_key[c.node_key] = c
  end

  local ctx = {
    bufnr = bufnr,
    options = config.options,
    containers_by_key = containers_by_key,
    entries_by_parent = index_by_parent(entries),
    comments_by_parent = index_comments_by_container(comments, containers),
  }

  return build_outline(chosen, ctx)
end

-- The `.yml` extension is a write-style alias for YAML; both filetypes
-- resolve to the same `yaml.toml` + `queries/yaml/sort-keys.scm` so the
-- yml/yaml relationship lives here with the builder, not in core.
M.filetypes = {
  yaml = "yaml",
  yml = "yaml",
}

return M
