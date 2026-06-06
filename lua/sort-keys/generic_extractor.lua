-- The generic extractor: driven entirely by a pack's `sort-keys.scm` captures,
-- so a JSON-shaped language needs no per-language Lua. It
-- supplies only the `collect` step (query triage by the sortkeys.* captures);
-- everything else — frame observation, comment folding, deep recursion, target
-- picking — comes from extract_support, which a custom extractor reuses too.
-- The parse-stage dispatcher (extract.lua) routes here when a pack ships no
-- custom extractor.

local support = require("sort-keys.extract_support")

local M = {}

local function collect(bufnr, root, query)
  local node_id_key = support.node_id_key

  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local function first_node(match, name)
    local id = cap_id[name]
    if not id then
      return nil
    end
    local v = match[id]
    if not v then
      return nil
    end
    -- iter_matches yields a list of nodes per capture on modern Neovim.
    if type(v) == "table" then
      return v[1]
    end
    return v
  end

  local containers = {}
  local containers_by_id = {}
  local raw_entries = {}
  local comments = {}
  local comment_ids = {}
  -- Pins and fences are collected as node-id SETS via their own captures,
  -- independent of which pattern captured the entry. So an order-sensitive
  -- member (a JS spread / computed key, a Ruby `**splat`) marked
  -- `@sortkeys.fence` keeps its flag even when a wildcard pattern also captures
  -- it as a plain entry and the dedup keeps the other copy.
  local pin_ids = {}
  local fence_ids = {}
  local seen_entry = {}

  for _, match, metadata in query:iter_matches(root, bufnr, 0, -1) do
    local cnode = first_node(match, "sortkeys.container")
    if cnode and metadata["sortkeys.kind"] then
      local rec = {
        node = cnode,
        range = { cnode:range() },
        kind = metadata["sortkeys.kind"],
      }
      containers[#containers + 1] = rec
      containers_by_id[node_id_key(cnode)] = rec
    end

    local comment_node = first_node(match, "sortkeys.comment")
    if comment_node then
      local parent = comment_node:parent()
      if parent then
        comment_ids[node_id_key(comment_node)] = true
        local pkey = node_id_key(parent)
        comments[pkey] = comments[pkey] or {}
        table.insert(comments[pkey], { node = comment_node, range = { comment_node:range() } })
      end
    end

    local pin_node = first_node(match, "sortkeys.pin")
    if pin_node then
      pin_ids[node_id_key(pin_node)] = true
    end
    local fence_node = first_node(match, "sortkeys.fence")
    if fence_node then
      fence_ids[node_id_key(fence_node)] = true
    end

    local enode = first_node(match, "sortkeys.entry")
    if enode and metadata["sortkeys.entry_kind"] then
      raw_entries[#raw_entries + 1] = {
        node = enode,
        range = { enode:range() },
        entry_kind = metadata["sortkeys.entry_kind"],
        key_node = first_node(match, "sortkeys.key"),
        value_node = first_node(match, "sortkeys.value"),
      }
    end
  end

  -- The wildcard array-element pattern `(array (_) @sortkeys.entry)` also
  -- captures comment children; drop those, and dedup entries captured twice,
  -- so a container never sees two entries with the same range. A fence is also
  -- a pin (it holds its slot and additionally blocks crossing).
  local entries_by_parent = {}
  for _, e in ipairs(raw_entries) do
    local id = node_id_key(e.node)
    if not comment_ids[id] and not seen_entry[id] then
      seen_entry[id] = true
      e.fence = fence_ids[id] or nil
      e.movable = not (pin_ids[id] or fence_ids[id])
      local parent = e.node:parent()
      if parent then
        local pkey = node_id_key(parent)
        entries_by_parent[pkey] = entries_by_parent[pkey] or {}
        table.insert(entries_by_parent[pkey], e)
      end
    end
  end

  return containers, containers_by_id, entries_by_parent, comments
end

---@param bufnr integer
---@param target table  -- { kind="cursor", pos={row,col} } | { kind="selection", srow, erow }
---@param pack table    -- { options, query_text, key_normalizer }
---@param deep boolean
---@return table|nil outline
function M.extract(bufnr, target, pack, deep)
  return support.run(bufnr, target, pack, deep, collect)
end

return M
