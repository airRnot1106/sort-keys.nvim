-- Python builder.
--
-- Python literal containers come in four surface shapes: `dictionary`,
-- `list`, `set`, and `tuple`. The first three are sortable; `tuple` is
-- intentionally excluded because `(x, y)` is positional and reordering it
-- changes meaning (think coordinates, return-multiple patterns).
--
-- Dictionary entries come in two AST forms: `pair` (regular `k: v`) and
-- `dictionary_splat` (`**other`). The splat is pinned (movable=false) because
-- `{**defaults, "a": 1}` and `{"a": 1, **defaults}` have different runtime
-- semantics — defaults precedes the explicit key or overrides it.
--
-- List/set elements include `list_splat` / `parenthesized_list_splat` (`*xs`)
-- which are likewise pinned. Pair keys that are an expression (attribute /
-- call / binary_operator / subscript) are also pinned because they may
-- evaluate to a runtime value whose ordering relative to the other keys
-- isn't predictable from source.

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

  -- The list/set element queries use a wildcard `(_)`, so a comment child of
  -- the container is captured twice — as an element and as a comment. Drop
  -- the entry duplicate so it isn't sorted as data AND attached as a comment.
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

  return containers, entries, comments
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

local function find_container_for_node(containers_by_key, node)
  return containers_by_key[node_id_key(node)]
end

-- The container that a value expression opens, if any. A `pair`'s value can
-- be a direct dictionary/list/set, or wrapped in a parenthesized_expression /
-- generator-like wrapper. v1 only follows a direct match; nested unwrapping
-- is over-engineering for the common case.
local function inner_container_of(value_node, containers_by_key)
  if not value_node then
    return nil
  end
  return find_container_for_node(containers_by_key, value_node)
end

-- ─── Python-specific entry classification ─────────────────────────────────────

-- A pair's `key` node decides both the sort_key and whether the entry is
-- safely reorderable. String / numeric / identifier / boolean / None keys are
-- compared by surface text (or normalized text for string literals); any
-- other key shape is a runtime expression we can't reorder past its siblings
-- without risking a change in evaluation order or duplicate-key behaviour.
local PINNED_KEY_TYPES = {
  attribute = true,
  call = true,
  subscript = true,
  binary_operator = true,
  unary_operator = true,
  boolean_operator = true,
  comparison_operator = true,
  conditional_expression = true,
  lambda = true,
  await = true,
  yield = true,
  parenthesized_expression = true,
}

local function classify_pair_key(key_node, bufnr)
  local t = key_node:type()
  local text = vim.treesitter.get_node_text(key_node, bufnr)

  if t == "string" or t == "concatenated_string" then
    return { sort_key = key_normalize.python(text), movable = true }
  end
  if t == "integer" or t == "float" or t == "identifier" then
    return { sort_key = text, movable = true }
  end
  if t == "true" or t == "false" or t == "none" then
    return { sort_key = text, movable = true }
  end
  if PINNED_KEY_TYPES[t] then
    return { sort_key = normalize_element_text(text), movable = false }
  end
  -- Unknown / future key shape: keep order, sort_key from surface text so the
  -- entry still has something printable in case the user introspects.
  return { sort_key = normalize_element_text(text), movable = false }
end

local function classify_entry(entry_node, bufnr)
  local t = entry_node:type()

  if t == "dictionary_splat" then
    -- `{**other}`: spread order is semantically significant.
    return { sort_key = "", movable = false }
  end

  if t == "list_splat" or t == "parenthesized_list_splat" then
    -- `[*it]` / `[(*it)]`: same as dict splat — keep position.
    return { sort_key = "", movable = false }
  end

  if t == "pair" then
    local key_node = entry_node:field("key")[1]
    if not key_node then
      return { sort_key = "", movable = false }
    end
    return classify_pair_key(key_node, bufnr)
  end

  -- Falls through for list/set element classification (handled at call-site).
  return nil
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
    local entry = {
      kind = e.entry_kind,
      range = e.range,
      movable = true,
      anchor = i,
      attached = {},
      child = nil,
    }

    if e.entry_kind == "pair" then
      local cls = classify_entry(e.node, ctx.bufnr)
      if cls then
        entry.sort_key = cls.sort_key
        entry.movable = cls.movable
      else
        entry.sort_key = ""
        entry.movable = false
      end

      if e.node:type() == "pair" then
        local value_field = e.node:field("value")
        local value_node = value_field and value_field[1] or nil
        local inner = inner_container_of(value_node, ctx.containers_by_key)
        if inner then
          entry.child = build_outline(inner, ctx)
        end
      end
    else
      -- list / set element
      local t = e.node:type()
      if t == "list_splat" or t == "parenthesized_list_splat" then
        entry.sort_key = normalize_element_text(vim.treesitter.get_node_text(e.node, ctx.bufnr))
        entry.movable = false
      else
        entry.sort_key = normalize_element_text(vim.treesitter.get_node_text(e.node, ctx.bufnr))
      end
      local inner = find_container_for_node(ctx.containers_by_key, e.node)
      if inner then
        entry.child = build_outline(inner, ctx)
      end
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
    entries_by_parent = index_by_parent(entries),
    comments_by_parent = index_by_parent(comments),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  python = "python",
}

return M
