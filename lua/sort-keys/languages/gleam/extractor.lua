-- Custom extractor for Gleam labelled arguments. A record/function call
-- (`arguments`) or a record definition (`data_constructor_arguments`) mixes
-- labelled args (`label: value`) with positional ones; only the labelled ones
-- have a key and may reorder, and a positional argument must keep its slot (it
-- binds by position), so positional args are pinned. A container is sortable
-- only when it has at least one labelled argument.
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
  local args_by_parent = {}
  local comments = {}

  local function push(parent, rec)
    if parent then
      local pk = node_id_key(parent)
      args_by_parent[pk] = args_by_parent[pk] or {}
      table.insert(args_by_parent[pk], rec)
    end
  end

  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local args = first(match, cap_id, "sortkeys.args") or first(match, cap_id, "sortkeys.def_args")
    if args then
      container_nodes[node_id_key(args)] = args
    end
    local arg = first(match, cap_id, "sortkeys.arg") or first(match, cap_id, "sortkeys.def_arg")
    if arg then
      push(arg:parent(), arg)
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
  for key, node in pairs(container_nodes) do
    local args = args_by_parent[key] or {}
    local entries, has_label = {}, false
    for _, arg in ipairs(args) do
      local label = arg:field("label")[1]
      if label then
        has_label = true
        entries[#entries + 1] = {
          node = arg,
          range = { arg:range() },
          entry_kind = "pair",
          key_node = label,
          value_node = arg:field("value")[1],
          movable = true,
        }
      else
        -- a positional argument binds by position: pin it in place.
        entries[#entries + 1] =
          { node = arg, range = { arg:range() }, entry_kind = "element", movable = false }
      end
    end
    if has_label then
      containers[#containers + 1] = { node = node, range = { node:range() }, kind = "object" }
      containers_by_id[key] = containers[#containers]
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
