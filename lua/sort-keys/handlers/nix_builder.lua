-- Nix builder.
--
-- Nix has six sortable container shapes (attrset, rec attrset, let,
-- list, formals, inherited_attrs) with three different separator policies
-- (`;`, `,`, whitespace), plus two AST quirks the other builders don't hit:
--
--   1. attrset / rec_attrset / let interpose a `binding_set` node between
--      the container and its bindings. Walking `entry:parent()` lands on
--      `binding_set` instead of the container, so this builder resolves
--      each entry to its nearest container ancestor.
--   2. `inherit` / `inherit_from` is one entry from the outer perspective
--      (the binding itself is pinned, by user policy) but exposes its
--      `inherited_attrs` child as another container so the identifier
--      order inside `inherit a c b;` can still sort.

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

local function pick_innermost(containers, target)
  if target.kind == "cursor" then
    return container_pick.for_cursor(containers, target.pos)
  end
  local candidates = {}
  for _, c in ipairs(containers) do
    if contains_range(c.range, target.range) then
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

local function normalize_element_text(text)
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  return (trimmed:gsub("%s+", " "))
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

-- Index entries by their *nearest container ancestor*. This is the variant
-- needed for Nix because attrset / rec_attrset / let wrap their bindings in
-- a `binding_set` node, so a flat parent() check would not reach the
-- container.
local function index_by_container_ancestor(entries, containers_by_key)
  local by_key = {}
  for _, item in ipairs(entries) do
    local cur = item.node:parent()
    while cur do
      local key = node_id_key(cur)
      if containers_by_key[key] then
        by_key[key] = by_key[key] or {}
        by_key[key][#by_key[key] + 1] = item
        break
      end
      cur = cur:parent()
    end
  end
  return by_key
end

local function index_comments_by_container_ancestor(comments, containers_by_key)
  local by_key = {}
  for _, item in ipairs(comments) do
    local cur = item.node:parent()
    while cur do
      local key = node_id_key(cur)
      if containers_by_key[key] then
        by_key[key] = by_key[key] or {}
        by_key[key][#by_key[key] + 1] = item
        break
      end
      cur = cur:parent()
    end
  end
  return by_key
end

local function find_container_for_node(containers_by_key, node)
  if not node then
    return nil
  end
  return containers_by_key[node_id_key(node)]
end

-- ─── per-container separator policy ───────────────────────────────────────────

-- Nix attrset / rec_attrset / let bindings end in `;` (every binding,
-- including the last, has a trailing semicolon). Formals use `,` between
-- entries; a trailing `,` after the last formal is a syntax error and
-- inserting one would corrupt the file. list_expression and inherited_attrs
-- are whitespace-gapped, so an empty separator lets the buffer gap carry
-- the spacing.
local function separator_for_container_node_type(node_type)
  if
    node_type == "attrset_expression"
    or node_type == "rec_attrset_expression"
    or node_type == "let_expression"
  then
    return ";", true
  end
  if node_type == "formals" then
    return ",", false
  end
  return "", true
end

-- ─── Nix entry classification ─────────────────────────────────────────────────

-- Returns the first node of a given type among `node`'s direct children
-- (named or anonymous). Used to dig out the `attrpath` of a `binding` and
-- the `inherited_attrs` of an `inherit` / `inherit_from`.
local function first_child_of_type(node, type_name)
  for child in node:iter_children() do
    if child:type() == type_name then
      return child
    end
  end
  return nil
end

-- Return the first identifier text inside an `inherit` / `inherit_from`
-- node's `inherited_attrs`. Used as the entry's sort_key — even though the
-- entry is pinned (movable=false), a sort_key keeps Outline contract happy
-- and the value is stable across runs since the identifier order can only
-- change via the inner sort.
local function first_inherited_identifier_text(inherit_node, bufnr)
  local attrs = first_child_of_type(inherit_node, "inherited_attrs")
  if not attrs then
    return ""
  end
  local first_id = attrs:named_child(0)
  if not first_id then
    return ""
  end
  return vim.treesitter.get_node_text(first_id, bufnr)
end

local function classify_entry(entry_node, bufnr)
  local t = entry_node:type()

  if t == "binding" then
    local attrpath = first_child_of_type(entry_node, "attrpath")
    if not attrpath then
      return { sort_key = "", movable = false, value_node = nil }
    end
    local key_text = vim.treesitter.get_node_text(attrpath, bufnr)
    return {
      sort_key = key_normalize.nix(key_text),
      movable = true,
      -- The value subtree may itself contain a sortable container.
      value_node = entry_node:named_child(entry_node:named_child_count() - 1),
    }
  end

  if t == "inherit" or t == "inherit_from" then
    -- The binding pins by user policy; the inner identifier list sorts via
    -- the inherit / inherit_from node *itself* exposed as an array
    -- container, so the cursor on `inherit` / `(expr)` resolves to that
    -- container instead of falling through to the outer attrset.
    return {
      sort_key = first_inherited_identifier_text(entry_node, bufnr),
      movable = false,
      value_node = entry_node,
    }
  end

  if t == "formal" then
    -- A formal is `identifier` or `identifier ? default_expr`; named_child(0)
    -- is always the identifier.
    local id = entry_node:named_child(0)
    if not id then
      return { sort_key = "", movable = false, value_node = nil }
    end
    return {
      sort_key = key_normalize.nix(vim.treesitter.get_node_text(id, bufnr)),
      movable = true,
      value_node = nil,
    }
  end

  if t == "ellipses" then
    -- Nix grammar forces `...` to be the last formal; pinning preserves
    -- that even when surrounding formals reorder.
    return { sort_key = "...", movable = false, value_node = nil }
  end

  if t == "identifier" then
    return {
      sort_key = key_normalize.nix(vim.treesitter.get_node_text(entry_node, bufnr)),
      movable = true,
      value_node = nil,
    }
  end

  -- Generic list element (variable_expression / integer_expression / etc.).
  return {
    sort_key = normalize_element_text(vim.treesitter.get_node_text(entry_node, bufnr)),
    movable = true,
    value_node = entry_node,
  }
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

  local raw = ctx.entries_by_container[container.node_key] or {}
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
    local cls = classify_entry(e.node, ctx.bufnr)
    local entry = {
      kind = e.entry_kind,
      range = e.range,
      sort_key = cls.sort_key,
      movable = cls.movable,
      anchor = i,
      attached = {},
      child = nil,
    }

    if cls.value_node then
      local inner = find_container_for_node(ctx.containers_by_key, cls.value_node)
      if inner then
        entry.child = build_outline(inner, ctx)
      end
    end

    outline_entries[#outline_entries + 1] = entry
  end

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_container[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  local sep, trailing = separator_for_container_node_type(container.node:type())

  return {
    kind = container.kind,
    range = container.range,
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
    options = config.options,
    containers_by_key = containers_by_key,
    entries_by_container = index_by_container_ancestor(entries, containers_by_key),
    comments_by_container = index_comments_by_container_ancestor(comments, containers_by_key),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  nix = "nix",
}

return M
