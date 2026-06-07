-- Custom extractor for Elixir maps / keyword lists.
--
-- A map's content node (`map_content`) is the container: it may hold a
-- `keywords` node (atom-key `%{a: 1}`), `=>` binary_operators (arrow
-- `%{"a" => 1}`), or both (mixed) — so the container is anchored at map_content
-- and ALL of those become entries, which keeps mixed maps from dropping
-- members and lets deep recursion reach a nested map (value -> map ->
-- map_content is one level down). A `keywords` node whose parent is NOT a
-- map_content is a keyword list / call-arg keyword list and is its own
-- container. A `|` map-update operator is not an arrow and is skipped (its
-- inner keywords sorts as its own container).
local support = require("sort-keys.parse.extract_support")

local M = {}

local function first(match, cap_id, name)
  local id = cap_id[name]
  local v = id and match[id]
  if not v then
    return nil
  end
  return type(v) == "table" and v[1] or v
end

-- The operator between left and right is `=>` (a real arrow), not `|` (update).
local function is_arrow(bufnr, binop)
  local left = binop:field("left")[1]
  local right = binop:field("right")[1]
  if not (left and right) then
    return false
  end
  local _, _, ler, lec = left:range()
  local rsr, rsc = right:range()
  return support.get_text(bufnr, ler, lec, rsr, rsc):find("=>", 1, true) ~= nil
end

local function make_pair(p)
  return {
    node = p,
    range = { p:range() },
    entry_kind = "pair",
    key_node = p:field("key")[1],
    value_node = p:field("value")[1],
    movable = true,
  }
end

local function make_arrow(b)
  return {
    node = b,
    range = { b:range() },
    entry_kind = "pair",
    key_node = b:field("left")[1],
    value_node = b:field("right")[1],
    movable = true,
  }
end

local function collect(bufnr, root, query)
  local node_id_key = support.node_id_key

  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local keywords_nodes = {}
  local pairs_by_parent = {}
  local map_contents = {}
  local arrows_by_mc, keywords_by_mc = {}, {}
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
      local parent = kw:parent()
      if parent and parent:type() == "map_content" then
        map_contents[node_id_key(parent)] = parent
        push(keywords_by_mc, parent, kw)
      end
    end

    local pair = first(match, cap_id, "sortkeys.pair")
    if pair then
      push(pairs_by_parent, pair:parent(), pair)
    end

    local arrow = first(match, cap_id, "sortkeys.arrow")
    if arrow and is_arrow(bufnr, arrow) then
      local parent = arrow:parent()
      if parent then
        map_contents[node_id_key(parent)] = parent
        push(arrows_by_mc, parent, arrow)
      end
    end

    local cm = first(match, cap_id, "sortkeys.comment")
    if cm then
      push(comments, cm:parent(), { node = cm, range = { cm:range() } })
    end
  end

  local containers, containers_by_id, entries_by_parent = {}, {}, {}

  local function register(node, entries)
    if #entries == 0 then
      return
    end
    local key = node_id_key(node)
    containers[#containers + 1] = { node = node, range = { node:range() }, kind = "object" }
    containers_by_id[key] = containers[#containers]
    entries_by_parent[key] = entries
  end

  -- map_content containers: arrows + the pairs of any keywords child.
  for key, mc in pairs(map_contents) do
    local entries = {}
    for _, arrow in ipairs(arrows_by_mc[key] or {}) do
      entries[#entries + 1] = make_arrow(arrow)
    end
    for _, kw in ipairs(keywords_by_mc[key] or {}) do
      for _, p in ipairs(pairs_by_parent[node_id_key(kw)] or {}) do
        entries[#entries + 1] = make_pair(p)
      end
    end
    register(mc, entries)
  end

  -- keyword lists / call-arg keyword lists: a keywords node not inside a map.
  for key, kw in pairs(keywords_nodes) do
    local parent = kw:parent()
    if not (parent and parent:type() == "map_content") then
      local entries = {}
      for _, p in ipairs(pairs_by_parent[key] or {}) do
        entries[#entries + 1] = make_pair(p)
      end
      register(kw, entries)
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
