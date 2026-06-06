-- Custom extractor for KDL. KDL has two "key" levels, like JSON: the named
-- `node`s in a document / children block are the outer keys, and a node's
-- `node_field` properties (key=value) are the inner keys. The cursor picks the
-- level — exactly as JSON sorts whichever object the cursor sits in:
--
--   * cursor on a property field  -> sort that node's properties by key
--   * cursor anywhere else (a node name, a positional arg, a children block)
--                                 -> sort the sibling nodes by node name
--
-- Only properties carry a key and may reorder; a node's positional arguments /
-- slashdash fields bind by position and are pinned. A node-as-container is
-- emitted only when the cursor is on one of its properties, so the level the
-- cursor is NOT on never shadows the other when pick_container takes the
-- smallest container.
local support = require("sort-keys.extract_support")
local pos = require("sort-keys.core.pos")

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

-- Trim a node's trailing terminator off its range so it ends at the last
-- content byte. A KDL node's slot delimiter — a newline OR a `;` — sits inside
-- the node's own range; left in place, each node carries its own terminator and
-- the gap between nodes is empty, so reordering strands the terminator on the
-- wrong node (`c 1; a 2` -> `a 2 c 1;`, which merges two nodes into one) and at
-- EOF the last node has no terminator to carry at all. Trimming it makes the
-- delimiter slot-bound, so render re-emits it between the new neighbours.
local function trim_end(bufnr, sr, sc, er, ec)
  while er > sr or (er == sr and ec > sc) do
    if ec == 0 then
      er = er - 1
      ec = #(vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or "")
    else
      local ch = vim.api.nvim_buf_get_text(bufnr, er, ec - 1, er, ec, {})[1]
      if ch == " " or ch == "\t" or ch == ";" then
        ec = ec - 1
      else
        break
      end
    end
  end
  return sr, sc, er, ec
end

-- A node's name is its first identifier / string child (after any type
-- annotation), used as the sort key when sorting sibling nodes.
local function node_name(node)
  for child in node:iter_children() do
    local t = child:type()
    if t == "identifier" or t == "string" then
      return child
    end
  end
  return nil
end

local function collect(bufnr, root, query, target)
  local node_id_key = support.node_id_key

  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local crow, ccol
  if target.kind == "cursor" then
    crow, ccol = target.pos[1], target.pos[2]
  else
    crow, ccol = target.srow, 0
  end

  local node_containers = {} -- document / node_children that hold sibling nodes
  local nodes = {}
  local nodes_by_parent = {} -- sibling nodes grouped by their container, one pass
  local fields_by_node = {}
  local comments = {}

  local function push(map, parent, rec)
    if parent then
      local pk = node_id_key(parent)
      map[pk] = map[pk] or {}
      table.insert(map[pk], rec)
    end
  end

  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local doc = first(match, cap_id, "sortkeys.doc")
    if doc then
      node_containers[node_id_key(doc)] = doc
    end
    local children = first(match, cap_id, "sortkeys.children")
    if children then
      node_containers[node_id_key(children)] = children
    end
    local node = first(match, cap_id, "sortkeys.node")
    if node then
      nodes[node_id_key(node)] = node
      push(nodes_by_parent, node:parent(), node)
    end
    local field = first(match, cap_id, "sortkeys.field")
    if field then
      push(fields_by_node, field:parent(), field)
    end
    local cm = first(match, cap_id, "sortkeys.comment")
    if cm then
      push(comments, cm:parent(), { node = cm, range = { cm:range() } })
    end
  end

  -- Which level does the target sit on? On a property field -> that node sorts
  -- its properties; otherwise the enclosing document / children block sorts its
  -- sibling nodes. A cursor uses point containment; a line-wise selection has no
  -- column, so it picks the SMALLEST property-bearing node whose rows cover the
  -- whole selection (selecting within one node sorts its properties; a selection
  -- that spans sibling nodes covers none and falls through to the node level).
  local function has_property(nkey)
    for _, f in ipairs(fields_by_node[nkey] or {}) do
      if field_prop(f) then
        return true
      end
    end
    return false
  end

  local on_prop_node
  if target.kind == "cursor" then
    for nkey, node in pairs(nodes) do
      for _, f in ipairs(fields_by_node[nkey] or {}) do
        if field_prop(f) and pos.contains({ f:range() }, crow, ccol) then
          on_prop_node = node
          break
        end
      end
      if on_prop_node then
        break
      end
    end
  else
    local best_area
    for nkey, node in pairs(nodes) do
      local r = { node:range() }
      if has_property(nkey) and pos.rows_cover(r, target.srow, target.erow) then
        local area = (r[3] - r[1]) * 1000000 + (r[4] - r[2])
        if not best_area or area < best_area then
          on_prop_node, best_area = node, area
        end
      end
    end
  end

  local containers, containers_by_id, entries_by_parent = {}, {}, {}

  if on_prop_node then
    local nkey = node_id_key(on_prop_node)
    local entries = {}
    for _, f in ipairs(fields_by_node[nkey] or {}) do
      local prop = field_prop(f)
      if prop then
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
    local rec = { node = on_prop_node, range = { on_prop_node:range() }, kind = "object" }
    containers[#containers + 1] = rec
    containers_by_id[nkey] = rec
    entries_by_parent[nkey] = entries
  else
    -- Sort sibling nodes by name in each document / children block.
    for ckey, cnode in pairs(node_containers) do
      local entries = {}
      for _, node in ipairs(nodes_by_parent[ckey] or {}) do
        local sr, sc, er, ec = node:range()
        local name = node_name(node)
        if name then
          entries[#entries + 1] = {
            node = node,
            range = { trim_end(bufnr, sr, sc, er, ec) },
            entry_kind = "pair",
            key_node = name,
            movable = true,
          }
        else
          -- A node with no name child can't be keyed; pin it so it holds its
          -- slot and is never dropped, instead of aborting the whole sort.
          entries[#entries + 1] = {
            node = node,
            range = { trim_end(bufnr, sr, sc, er, ec) },
            entry_kind = "element",
            movable = false,
          }
        end
      end
      if #entries > 0 then
        local rec = { node = cnode, range = { cnode:range() }, kind = "object" }
        containers[#containers + 1] = rec
        containers_by_id[ckey] = rec
        entries_by_parent[ckey] = entries
      end
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
  -- KDL fields are space-separated, but a `\` line continuation in the
  -- inter-entry gap would be misread as a delimiter by the generic separator
  -- probe, so pin it to "" rather than let extract_support observe it. A fresh
  -- pack is built so the shared (memoized) pack.options is never mutated.
  local kdl_pack = vim.tbl_extend("force", pack, {
    options = vim.tbl_extend("force", pack.options, { separator = "" }),
  })
  return support.run(bufnr, target, kdl_pack, deep, function(b, root, query)
    return collect(b, root, query, target)
  end)
end

return M
