-- Custom extractor for Go. A `literal_value` is the same node for a struct
-- literal, a map literal, a slice, and a positional struct literal — only the
-- keyed ones (struct-by-field, map) are safely sortable, and that can't be
-- tagged by a static query, so the kind is decided here: a literal_value is an
-- object iff it has keyed_element children (positional/slice literals are left
-- untouched so their order is never changed). Struct definitions
-- (field_declaration_list) and import blocks (import_spec_list) are also
-- handled. It supplies only `collect`; everything downstream is shared.

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

-- The container nested under a keyed_element's value, for deep recursion: the
-- value wraps a composite_literal (directly for `T{...}`, under a
-- unary_expression for `&T{...}`) whose body is the inner literal_value.
local function inner_literal_value(keyed)
  local value = keyed:field("value")[1]
  if not value then
    return nil
  end
  local function find_composite(node, depth)
    if node:type() == "composite_literal" then
      return node
    end
    if depth >= 2 then
      return nil
    end
    for child in node:iter_children() do
      if child:named() then
        local found = find_composite(child, depth + 1)
        if found then
          return found
        end
      end
    end
    return nil
  end
  local cl = find_composite(value, 0)
  return cl and cl:field("body")[1] or nil
end

local function collect(bufnr, root, query)
  local node_id_key = support.node_id_key

  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local literal_values, field_lists, import_lists = {}, {}, {}
  local keyed_by_parent, fields_by_parent, imports_by_parent = {}, {}, {}
  local comments = {}

  local function push(map, parent, rec)
    if parent then
      local pk = node_id_key(parent)
      map[pk] = map[pk] or {}
      table.insert(map[pk], rec)
    end
  end

  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local lv = first(match, cap_id, "sortkeys.literal_value")
    if lv then
      literal_values[node_id_key(lv)] = lv
    end
    local fl = first(match, cap_id, "sortkeys.field_list")
    if fl then
      field_lists[node_id_key(fl)] = fl
    end
    local il = first(match, cap_id, "sortkeys.import_list")
    if il then
      import_lists[node_id_key(il)] = il
    end

    local keyed = first(match, cap_id, "sortkeys.keyed")
    if keyed then
      push(keyed_by_parent, keyed:parent(), keyed)
    end
    local field = first(match, cap_id, "sortkeys.field")
    if field then
      push(fields_by_parent, field:parent(), field)
    end
    local import = first(match, cap_id, "sortkeys.import")
    if import then
      push(imports_by_parent, import:parent(), import)
    end
    local cm = first(match, cap_id, "sortkeys.comment")
    if cm then
      push(comments, cm:parent(), { node = cm, range = { cm:range() } })
    end
  end

  local containers, containers_by_id, entries_by_parent = {}, {}, {}

  local function add_container(node, kind, raw_entries, make)
    local key = node_id_key(node)
    local rec = { node = node, range = { node:range() }, kind = kind }
    containers[#containers + 1] = rec
    containers_by_id[key] = rec
    local list = {}
    for _, e in ipairs(raw_entries) do
      list[#list + 1] = make(e)
    end
    entries_by_parent[key] = list
  end

  -- struct / map literals: object iff they have keyed elements.
  for key, lv in pairs(literal_values) do
    local keyed = keyed_by_parent[key]
    if keyed then
      add_container(lv, "object", keyed, function(k)
        return {
          node = k,
          range = { k:range() },
          entry_kind = "pair",
          key_node = k:field("key")[1],
          value_node = inner_literal_value(k) or k:field("value")[1],
          movable = true,
        }
      end)
    end
  end

  -- struct definitions: newline-separated named fields. An embedded field
  -- (`io.Reader`) has no name; pin it (element, movable=false) so it round-trips
  -- in place — never dropped, and its method-promotion order is unchanged —
  -- while named fields sort around it.
  for key, fl in pairs(field_lists) do
    local fields = fields_by_parent[key] or {}
    add_container(fl, "object", fields, function(f)
      local name = f:field("name")[1]
      if name then
        return {
          node = f,
          range = { f:range() },
          entry_kind = "pair",
          key_node = name,
          movable = true,
        }
      end
      return { node = f, range = { f:range() }, entry_kind = "element", movable = false }
    end)
  end

  -- import blocks: sort by path text (a pair keyed on the path, so an aliased
  -- import still sorts by its path).
  for key, il in pairs(import_lists) do
    local imports = imports_by_parent[key] or {}
    add_container(il, "array", imports, function(im)
      return {
        node = im,
        range = { im:range() },
        entry_kind = "pair",
        key_node = im:field("path")[1] or im,
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
