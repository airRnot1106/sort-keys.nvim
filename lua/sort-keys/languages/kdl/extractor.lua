-- Custom extractor for KDL. A node's children are node_fields, each wrapping
-- either a property (key=value) or a positional argument / slashdash marker.
-- Only properties have a key and may reorder; args/markers are pinned so they
-- hold their slot and are never absorbed into a gap (KDL allows args and props
-- to interleave). A node is sortable only when it has at least one property.
local support = require("sort-keys.extract_support")

local M = {}

local function first(match, cap_id, name)
  local id = cap_id[name]
  local v = id and match[id]
  if not v then
    return nil
  end
  return type(v) == "table" and v[1] or v
end

-- The prop node inside a node_field, or nil for an argument / slashdash field.
local function field_prop(node_field)
  for child in node_field:iter_children() do
    if child:type() == "prop" then
      return child
    end
  end
  return nil
end

local function prop_key(prop)
  for child in prop:iter_children() do
    local t = child:type()
    if t == "identifier" or t == "string" then
      return child
    end
  end
  return nil
end

local function collect(bufnr, root, query)
  local node_id_key = support.node_id_key

  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local nodes = {}
  local fields_by_node = {}
  local comments = {}

  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local node = first(match, cap_id, "sortkeys.node")
    if node then
      nodes[node_id_key(node)] = node
    end
    local field = first(match, cap_id, "sortkeys.field")
    if field then
      local parent = field:parent()
      if parent then
        local pk = node_id_key(parent)
        fields_by_node[pk] = fields_by_node[pk] or {}
        table.insert(fields_by_node[pk], field)
      end
    end
    local cm = first(match, cap_id, "sortkeys.comment")
    if cm then
      local parent = cm:parent()
      if parent then
        local pk = node_id_key(parent)
        comments[pk] = comments[pk] or {}
        table.insert(comments[pk], { node = cm, range = { cm:range() } })
      end
    end
  end

  local containers, containers_by_id, entries_by_parent = {}, {}, {}
  for key, node in pairs(nodes) do
    local fields = fields_by_node[key] or {}
    local entries = {}
    local has_prop = false
    for _, f in ipairs(fields) do
      local prop = field_prop(f)
      if prop then
        has_prop = true
        entries[#entries + 1] = {
          node = f,
          range = { f:range() },
          entry_kind = "pair",
          key_node = prop_key(prop),
          movable = true,
        }
      else
        -- a positional argument / slashdash field: pin it in place.
        entries[#entries + 1] = {
          node = f,
          range = { f:range() },
          entry_kind = "element",
          movable = false,
        }
      end
    end
    if has_prop then
      local rec = { node = node, range = { node:range() }, kind = "object" }
      containers[#containers + 1] = rec
      containers_by_id[key] = rec
      entries_by_parent[key] = entries
    end
  end

  return containers, containers_by_id, entries_by_parent, comments
end

---@param bufnr integer
---@param target table
---@param pack table
---@param deep boolean
---@return table|nil outline
function M.extract(bufnr, target, pack, deep)
  return support.run(bufnr, target, pack, deep, collect)
end

return M
