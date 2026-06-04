-- Custom extractor for Elixir maps / keyword lists. Atom-key maps and keyword
-- lists hold their pairs under a `keywords` node (that node is the container);
-- arrow maps (`"a" => 1`) hold binary_operators directly under `map_content`
-- (that node is the container). Only `collect` differs; the rest is shared.
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

  local keywords_nodes = {}
  local pairs_by_parent = {}
  local arrows_by_parent = {}
  local map_contents = {}
  local comments = {}

  local function push(map, parent, rec)
    if parent then
      local pk = node_id_key(parent)
      map[pk] = map[pk] or {}
      table.insert(map[pk], rec)
    end
  end

  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local kw = first(match, cap_id, "sortkeys.keywords")
    if kw then
      keywords_nodes[node_id_key(kw)] = kw
    end
    local pair = first(match, cap_id, "sortkeys.pair")
    if pair then
      push(pairs_by_parent, pair:parent(), pair)
    end
    local arrow = first(match, cap_id, "sortkeys.arrow")
    if arrow then
      local parent = arrow:parent()
      if parent then
        map_contents[node_id_key(parent)] = parent
        push(arrows_by_parent, parent, arrow)
      end
    end
    local cm = first(match, cap_id, "sortkeys.comment")
    if cm then
      push(comments, cm:parent(), { node = cm, range = { cm:range() } })
    end
  end

  local containers, containers_by_id, entries_by_parent = {}, {}, {}

  local function add(node, raw_entries, make)
    if not raw_entries or #raw_entries == 0 then
      return
    end
    local key = node_id_key(node)
    containers[#containers + 1] = { node = node, range = { node:range() }, kind = "object" }
    containers_by_id[key] = containers[#containers]
    local list = {}
    for _, e in ipairs(raw_entries) do
      list[#list + 1] = make(e)
    end
    entries_by_parent[key] = list
  end

  for key, kw in pairs(keywords_nodes) do
    add(kw, pairs_by_parent[key], function(p)
      return {
        node = p,
        range = { p:range() },
        entry_kind = "pair",
        key_node = p:field("key")[1],
        value_node = p:field("value")[1],
        movable = true,
      }
    end)
  end

  for key, mc in pairs(map_contents) do
    add(mc, arrows_by_parent[key], function(b)
      return {
        node = b,
        range = { b:range() },
        entry_kind = "pair",
        key_node = b:field("left")[1],
        value_node = b:field("right")[1],
        movable = true,
      }
    end)
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
