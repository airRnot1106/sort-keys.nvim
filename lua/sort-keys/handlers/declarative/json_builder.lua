local key_normalize = require("sort-keys.strategies.key_normalize")

local M = {}

local CAPTURE = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  key = "sortkeys.key",
  value = "sortkeys.value",
}

local META = {
  kind = "sortkeys.kind",
  entry_kind = "sortkeys.entry_kind",
}

local function node_range(node)
  local sr, sc, er, ec = node:range()
  return { sr, sc, er, ec }
end

local function node_id_key(node)
  local sr, sc, er, ec = node:range()
  return string.format("%s:%d:%d:%d:%d", node:type(), sr, sc, er, ec)
end

-- ─── range geometry ────────────────────────────────────────────────────

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
  -- Lexicographic "size" suitable for picking innermost.
  return (r[3] - r[1]) * 1000000 + (r[4] - r[2])
end

local function pick_innermost(containers, target)
  local candidates = {}
  for _, c in ipairs(containers) do
    local hit = false
    if target.kind == "cursor" then
      hit = pos_inside(c.range, target.pos[1], target.pos[2])
    elseif target.kind == "selection" then
      hit = contains_range(c.range, target.range)
    end
    if hit then
      candidates[#candidates + 1] = c
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

-- ─── element sort_key normalization ──────────────────────────────────────

local function normalize_element_text(text)
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  return (trimmed:gsub("%s+", " "))
end

-- ─── query traversal ───────────────────────────────────────────────────

local function collect_matches(bufnr, root, query)
  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local containers = {}
  local entries = {}

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
          key_node = first_node(match, CAPTURE.key),
          value_node = first_node(match, CAPTURE.value),
        }
      end
    end
  end

  return containers, entries
end

local function index_entries_by_parent(entries)
  local by_parent = {}
  for _, e in ipairs(entries) do
    local parent = e.node:parent()
    if parent then
      local pk = node_id_key(parent)
      by_parent[pk] = by_parent[pk] or {}
      by_parent[pk][#by_parent[pk] + 1] = e
    end
  end
  return by_parent
end

local function find_container_for_node(containers_by_key, node)
  return containers_by_key[node_id_key(node)]
end

-- ─── capability validation ─────────────────────────────────────────────

local function capability_allows(kind, toml)
  if kind == "object" then
    return toml.can_sort_object == true
  end
  if kind == "array" then
    return toml.can_sort_array == true
  end
  return false
end

local function separator_for(kind, toml)
  if kind == "object" then
    return toml.default_separator_object
  end
  return toml.default_separator_array
end

-- ─── outline construction ──────────────────────────────────────────────

local function build_outline(container, ctx)
  if not capability_allows(container.kind, ctx.toml) then
    return nil
  end

  local raw = ctx.entries_by_parent[container.node_key] or {}
  -- Sort entries by source position to fix `anchor` independent of query order.
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
      range = e.range,
      movable = true,
      anchor = i,
      attached = {},
      child = nil,
    }

    if e.entry_kind == "pair" then
      if not e.key_node then
        return nil
      end
      local key_text = vim.treesitter.get_node_text(e.key_node, ctx.bufnr)
      entry.sort_key = key_normalize.json(key_text)
      if e.value_node then
        local inner = find_container_for_node(ctx.containers_by_key, e.value_node)
        if inner then
          entry.child = build_outline(inner, ctx)
        end
      end
    else
      local elem_text = vim.treesitter.get_node_text(e.node, ctx.bufnr)
      entry.sort_key = normalize_element_text(elem_text)
      local inner = find_container_for_node(ctx.containers_by_key, e.node)
      if inner then
        entry.child = build_outline(inner, ctx)
      end
    end

    outline_entries[#outline_entries + 1] = entry
  end

  return {
    kind = container.kind,
    range = container.range,
    separator = separator_for(container.kind, ctx.toml),
    entries = outline_entries,
  }
end

-- ─── public entry point ────────────────────────────────────────────────

local function validate_toml(toml)
  local required = {
    "can_sort_object",
    "can_sort_array",
    "can_deep",
    "key_quoting",
    "default_separator_object",
    "default_separator_array",
  }
  for _, k in ipairs(required) do
    if toml[k] == nil then
      return false
    end
  end
  return true
end

---@param bufnr integer
---@param target table
---@param config { filetype: string, query_text: string, toml: table }
---@return table|nil
function M.build(bufnr, target, config)
  if not validate_toml(config.toml) then
    return nil
  end

  -- Parser availability is environmental: a missing language is not a plugin
  -- bug, so we surface it via the same `nil Outline → notify` path the rest
  -- of the build uses. Query syntax errors below are plugin/user bugs and
  -- are intentionally allowed to propagate.
  local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr, config.filetype)
  if not parser_ok or parser == nil then
    return nil
  end
  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse(config.filetype, config.query_text)

  local containers, entries = collect_matches(bufnr, root, query)
  if #containers == 0 then
    return nil
  end

  local chosen = pick_innermost(containers, target)
  if not chosen then
    return nil
  end

  local containers_by_key = {}
  for _, c in ipairs(containers) do
    containers_by_key[c.node_key] = c
  end

  local ctx = {
    bufnr = bufnr,
    toml = config.toml,
    containers_by_key = containers_by_key,
    entries_by_parent = index_entries_by_parent(entries),
  }

  return build_outline(chosen, ctx)
end

return M
