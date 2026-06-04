-- Custom extractor for Lua tables — the canonical irregular-AST case the
-- generic, query-driven extractor can't handle: a `table_constructor` is the
-- same node whether it is object-like (`{ a = 1 }`) or array-like (`{ 1, 2 }`),
-- so its kind must be VOTED from the fields rather than tagged statically.
--
-- It supplies only `collect`; frame observation, comment folding, deep
-- recursion, and target picking all come from extract_support, so this stays
-- small. A field with a `name` is a keyed pair; a positional field is an
-- element — movable in a pure array, but pinned inside an object/mixed table
-- where its implicit index is meaningful.

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

local function collect(bufnr, root, query)
  local node_id_key = support.node_id_key

  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local container_nodes = {}
  local fields_by_table = {}
  local comments = {}
  local seen_field = {}

  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local cnode = first(match, cap_id, "sortkeys.container")
    if cnode then
      container_nodes[#container_nodes + 1] = cnode
    end

    local fnode = first(match, cap_id, "sortkeys.field")
    if fnode then
      local id = node_id_key(fnode)
      local parent = fnode:parent()
      if parent and not seen_field[id] then
        seen_field[id] = true
        local pkey = node_id_key(parent)
        fields_by_table[pkey] = fields_by_table[pkey] or {}
        table.insert(fields_by_table[pkey], fnode)
      end
    end

    local cmnode = first(match, cap_id, "sortkeys.comment")
    if cmnode then
      local parent = cmnode:parent()
      if parent then
        local pkey = node_id_key(parent)
        comments[pkey] = comments[pkey] or {}
        table.insert(comments[pkey], { node = cmnode, range = { cmnode:range() } })
      end
    end
  end

  local containers, containers_by_id, entries_by_parent = {}, {}, {}
  for _, cnode in ipairs(container_nodes) do
    local ckey = node_id_key(cnode)
    local fields = fields_by_table[ckey] or {}

    local has_keyed = false
    for _, f in ipairs(fields) do
      if f:field("name")[1] then
        has_keyed = true
        break
      end
    end
    local kind = has_keyed and "object" or "array"

    local rec = { node = cnode, range = { cnode:range() }, kind = kind }
    containers[#containers + 1] = rec
    containers_by_id[ckey] = rec

    local list = {}
    for _, f in ipairs(fields) do
      local name = f:field("name")[1]
      local value = f:field("value")[1]
      if name then
        list[#list + 1] = {
          node = f,
          range = { f:range() },
          entry_kind = "pair",
          key_node = name,
          value_node = value,
          movable = true,
        }
      else
        list[#list + 1] = {
          node = f,
          range = { f:range() },
          entry_kind = "element",
          value_node = value,
          -- A positional field keeps its slot inside an object/mixed table
          -- (its implicit index matters); in a pure array it is sortable.
          movable = kind == "array",
        }
      end
    end
    entries_by_parent[ckey] = list
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
