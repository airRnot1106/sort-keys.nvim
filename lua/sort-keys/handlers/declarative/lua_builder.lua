-- Lua declarative builder.
--
-- Lua's `table_constructor` is one AST node for both object-like
-- (`{a=1, b=2}`) and array-like (`{1, 2, 3}`) tables. Kind cannot be set
-- from the query's `#set! sortkeys.kind` (as json/javascript do) — it has to
-- be derived after inspecting each field. The voting rule: any keyed field
-- → kind = "object" (positional fields pin to preserve their implicit
-- indices); all-positional → kind = "array".

local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")
local container_pick = require("sort-keys.core.container_pick")

local M = {}

local CAPTURE = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  comment = "sortkeys.comment",
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

  for _, match, _metadata in query:iter_matches(root, bufnr, 0, -1, { all = true }) do
    local container_node = first_node(match, CAPTURE.container)
    if container_node then
      -- Unlike json_builder which gates containers on `sortkeys.kind`
      -- metadata, Lua's container kind is computed in build_outline.
      containers[#containers + 1] = {
        node = container_node,
        range = node_range(container_node),
        node_key = node_id_key(container_node),
      }
    end

    local entry_node = first_node(match, CAPTURE.entry)
    if entry_node then
      entries[#entries + 1] = {
        node = entry_node,
        range = node_range(entry_node),
      }
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

-- ─── Lua field classification ─────────────────────────────────────────────────

-- A tree-sitter-lua `field` node takes four shapes:
--   identifier `=` value          — bare key, sortable
--   `[` string `]` `=` value      — bracket-string key, sortable
--   `[` other-expr `]` `=` value  — bracket-computed key, pinned
--   expression                    — positional element, pinned in object mode,
--                                   sortable by surface text in array mode
-- The distinguishing signal between a bare-key field and a positional field
-- whose value happens to be an identifier (e.g., `plenary_dir,`) is the
-- *named child count*: keyed forms always have two named children (key +
-- value); positional has exactly one (the value itself).
local function classify_entry(field_node, bufnr)
  if field_node:named_child_count() <= 1 then
    return {
      sort_key = normalize_element_text(vim.treesitter.get_node_text(field_node, bufnr)),
      movable = false,
      kind_vote = "array",
      key_node = nil,
    }
  end

  local c0 = field_node:child(0)
  if c0 and c0:type() == "[" then
    local c1 = field_node:child(1)
    if c1 and c1:type() == "string" then
      return {
        sort_key = key_normalize.lua(vim.treesitter.get_node_text(c1, bufnr)),
        movable = true,
        kind_vote = "object",
        key_node = c1,
      }
    end
    return { sort_key = "", movable = false, kind_vote = "object", key_node = nil }
  end

  if c0 and c0:type() == "identifier" then
    return {
      sort_key = key_normalize.lua(vim.treesitter.get_node_text(c0, bufnr)),
      movable = true,
      kind_vote = "object",
      key_node = c0,
    }
  end

  return { sort_key = "", movable = false, kind_vote = "object", key_node = nil }
end

-- A field's value subtree: for bare/bracket-string/bracket-computed, the value
-- is the last named child (after the `=`); for positional, the value IS the
-- field's sole named child. Used to recurse into nested table_constructor
-- children for :DeepSortKeys.
local function value_node_of(field_node)
  local n = field_node:named_child_count()
  if n == 0 then
    return nil
  end
  return field_node:named_child(n - 1)
end

-- ─── capability + build_outline ───────────────────────────────────────────────

local function capability_allows(kind, toml)
  if kind == "object" then
    return toml.can_sort_object == true
  end
  if kind == "array" then
    return toml.can_sort_array == true
  end
  return false
end

local function build_outline(container, ctx)
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
  local votes_object = 0
  local classifications = {}
  for i, e in ipairs(sorted_raw) do
    local cls = classify_entry(e.node, ctx.bufnr)
    classifications[i] = cls
    if cls.kind_vote == "object" then
      votes_object = votes_object + 1
    end

    local entry = {
      kind = "pair",
      range = e.range,
      sort_key = cls.sort_key,
      movable = cls.movable,
      anchor = i,
      attached = {},
      child = nil,
    }

    local value_node = value_node_of(e.node)
    if value_node then
      local inner = find_container_for_node(ctx.containers_by_key, value_node)
      if inner then
        entry.child = build_outline(inner, ctx)
      end
    end

    outline_entries[#outline_entries + 1] = entry
  end

  local kind = (votes_object == 0) and "array" or "object"
  if not capability_allows(kind, ctx.toml) then
    return nil
  end

  if kind == "array" then
    -- All-positional table: every entry is an element, all movable.
    for i, entry in ipairs(outline_entries) do
      entry.kind = "element"
      entry.movable = true
      entry.sort_key = classifications[i].sort_key
    end
  end

  if ctx.toml.comment_aware then
    local container_comments = ctx.comments_by_parent[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  return {
    kind = kind,
    range = container.range,
    structural_separator = ctx.toml.structural_separator,
    trailing_separator_allowed = ctx.toml.trailing_separator_allowed == true,
    entries = outline_entries,
  }
end

local function validate_toml(toml)
  local required = {
    "can_sort_object",
    "can_sort_array",
    "can_deep",
    "key_quoting",
  }
  for _, k in ipairs(required) do
    if toml[k] == nil then
      return false
    end
  end
  return true
end

---@param bufnr integer
---@param target table
---@param config { filetype: string, query_text: string, toml: table }
---@return table|nil
function M.build(bufnr, target, config)
  if not validate_toml(config.toml) then
    return nil
  end

  local lang = config.toml.parser_lang or config.filetype
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
    toml = config.toml,
    containers_by_key = containers_by_key,
    entries_by_parent = index_by_parent(entries),
    comments_by_parent = index_by_parent(comments),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  lua = "lua",
}

return M
