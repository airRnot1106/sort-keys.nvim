-- Rust builder.
--
-- Three container shapes reach this layer:
--   field_declaration_list — struct-definition body (entries: field_declaration)
--   field_initializer_list — struct-literal body    (entries: field_initializer
--                                                    / shorthand_field_initializer
--                                                    / base_field_initializer)
--   use_list               — grouped use entries   (entries: identifier / self /
--                                                    scoped_identifier /
--                                                    scoped_use_list / use_as_clause)
--
-- `base_field_initializer` (`..base`) is pinned movable=false because the
-- struct-update tail must remain after the field initializers for the
-- grammar to accept the expression. Every other Rust-specific concern
-- (attributes, doc comments) is delegated to `core/comment_attach` via the
-- `attribute_item` / `line_comment` / `block_comment` captures: an attribute
-- preceding a field plays the same structural role as a leading comment, so
-- it travels with the next entry without any policy-layer changes.
--
-- Deep recursion: a `field_initializer`'s value can be a `struct_expression`
-- whose child is another `field_initializer_list`; a `scoped_use_list`'s
-- child is another `use_list`. The captured-container lookup is by node
-- identity, so we walk one level of children when the entry's own node
-- isn't a container but might wrap one.

local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")
local container_pick = require("sort-keys.core.container_pick")

local M = {}

local CAPTURE = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  key = "sortkeys.key",
  value = "sortkeys.value",
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
  -- Selection target: pick the smallest captured container that fully covers
  -- target.range. Single linear pass, no sort.
  local best, best_area = nil, nil
  for _, c in ipairs(containers) do
    if contains_range(c.range, target.range) then
      local a = range_area(c.range)
      if best_area == nil or a < best_area then
        best, best_area = c, a
      end
    end
  end
  return best
end

-- ─── query traversal ──────────────────────────────────────────────────────────

local function collect_matches(bufnr, root, query)
  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local containers = {}
  local entry_candidates = {}
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
        entry_candidates[#entry_candidates + 1] = {
          node = entry_node,
          range = node_range(entry_node),
          entry_kind = entry_kind,
          key_node = first_node(match, CAPTURE.key),
          value_node = first_node(match, CAPTURE.value),
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

  -- The use_list entry query is a wildcard `(use_list (_) @sortkeys.entry)`
  -- so it also captures direct comment / attribute children. Drop entries
  -- whose node was also captured as a comment to avoid sorting them as data
  -- and attaching them as comments at the same time (the Python/JSON
  -- builders use the same dedup trick).
  local comment_ids = {}
  for _, c in ipairs(comments) do
    comment_ids[node_id_key(c.node)] = true
  end
  local entries = {}
  for _, e in ipairs(entry_candidates) do
    if not comment_ids[node_id_key(e.node)] then
      entries[#entries + 1] = e
    end
  end

  -- Built here (not at the call site) because each container already carries
  -- its own node_key — re-walking the list in M.build was wasted work.
  local containers_by_key = {}
  for _, c in ipairs(containers) do
    containers_by_key[c.node_key] = c
  end

  return containers, entries, comments, containers_by_key
end

local function index_by_parent(items)
  local by_parent = {}
  for _, item in ipairs(items) do
    local parent = item.node:parent()
    if parent then
      local pk = node_id_key(parent)
      by_parent[pk] = by_parent[pk] or {}
      by_parent[pk][#by_parent[pk] + 1] = item
    end
  end
  return by_parent
end

-- Look up an inner captured container reachable from `node`. Two cases the
-- Rust grammar imposes a one-level wrapper for:
--   field_initializer.value = struct_expression(field_initializer_list)
--   use_list child         = scoped_use_list(<scope>, use_list)
-- The walk is **one level deep**: it matches the documented wrappers and
-- nothing more. Wrapping a struct literal in a call (`Some(Foo { ... })`),
-- a parenthesized expression, or a box (`Box::new(Foo { ... })`) is v1
-- out-of-scope — matching the Python builder's `inner_container_of` which
-- also refuses to unwrap parenthesized_expression / generator-like wrappers.
local function find_inner_container_within(containers_by_key, node)
  if not node then
    return nil
  end
  local direct = containers_by_key[node_id_key(node)]
  if direct then
    return direct
  end
  for child in node:iter_children() do
    local c = containers_by_key[node_id_key(child)]
    if c then
      return c
    end
  end
  return nil
end

-- ─── Rust-specific entry classification ──────────────────────────────────────

local function classify_entry(entry, bufnr)
  local node = entry.node
  local t = node:type()

  if t == "base_field_initializer" then
    -- `..base` must trail the explicit fields; reordering past them would
    -- yield a syntactically invalid struct expression.
    return { sort_key = "", movable = false }
  end

  -- field_declaration / field_initializer / shorthand_field_initializer all
  -- arrive with @sortkeys.key captured (the .scm query mandates the field
  -- accessor / inner identifier), so entry.key_node is always present here.
  if t == "field_declaration" or t == "field_initializer" or t == "shorthand_field_initializer" then
    local key_text = vim.treesitter.get_node_text(entry.key_node, bufnr)
    return { sort_key = key_normalize.rust(key_text), movable = true }
  end

  -- use_list element: identifier / self / scoped_identifier / scoped_use_list
  -- / use_as_clause. The surface text becomes the sort_key. Block and line
  -- comments are valid grammar extras anywhere in the entry (e.g.
  -- `A /* note */ as Aliased`); we strip them before normalizing so an inline
  -- comment edit never silently reorders the import list.
  local text = vim.treesitter.get_node_text(node, bufnr)
  text = text:gsub("/%*.-%*/", " ")
  text = text:gsub("//[^\n]*", " ")
  text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  return { sort_key = key_normalize.rust(text), movable = true }
end

-- ─── capability + build_outline ──────────────────────────────────────────────

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

  local raw = ctx.entries_by_parent[container.node_key] or {}
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
    local cls = classify_entry(e, ctx.bufnr)
    local entry = {
      kind = e.entry_kind,
      range = e.range,
      sort_key = cls.sort_key,
      movable = cls.movable,
      anchor = i,
      attached = {},
      child = nil,
    }

    -- Deep recursion. For field_initializer with a value, walk into the
    -- struct_expression's children to find the inner field_initializer_list.
    -- For use_list members that are themselves scoped_use_list, walk into
    -- the wrapper to find the inner use_list.
    local probe = e.value_node or e.node
    local inner = find_inner_container_within(ctx.containers_by_key, probe)
    if inner and inner.node_key ~= container.node_key then
      entry.child = build_outline(inner, ctx)
    end

    outline_entries[#outline_entries + 1] = entry
  end

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_parent[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  return {
    kind = container.kind,
    range = container.range,
    structural_separator = ctx.options.structural_separator,
    trailing_separator_allowed = ctx.options.trailing_separator_allowed == true,
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

  local containers, entries, comments, containers_by_key = collect_matches(bufnr, root, query)
  if #containers == 0 then
    return nil
  end

  local chosen = pick_innermost(containers, target)
  if not chosen then
    return nil
  end

  local ctx = {
    bufnr = bufnr,
    options = config.options,
    containers_by_key = containers_by_key,
    entries_by_parent = index_by_parent(entries),
    comments_by_parent = index_by_parent(comments),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  rust = "rust",
}

return M
