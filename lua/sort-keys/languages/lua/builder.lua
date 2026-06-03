-- Lua builder.
--
-- Lua's `table_constructor` is one AST node for both object-like
-- (`{a=1, b=2}`) and array-like (`{1, 2, 3}`) tables. Kind cannot be set
-- from the query's `#set! sortkeys.kind` (as json/javascript do) — it has to
-- be derived after inspecting each field. The voting rule: any keyed field
-- → kind = "object" (positional fields pin to preserve their implicit
-- indices); all-positional → kind = "array".

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

local CAPTURE = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  comment = "sortkeys.comment",
}

-- ─── query traversal (local — Lua skips the `sortkeys.kind` gate that
--                     standard collect_matches imposes, because kind is
--                     voted post-classification) ───────────────────────────

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
      containers[#containers + 1] = {
        node = container_node,
        range = h.node_range(container_node),
        node_key = h.node_id_key(container_node),
      }
    end

    local entry_node = first_node(match, CAPTURE.entry)
    if entry_node then
      entries[#entries + 1] = {
        node = entry_node,
        range = h.node_range(entry_node),
      }
    end

    local comment_node = first_node(match, CAPTURE.comment)
    if comment_node then
      comments[#comments + 1] = {
        node = comment_node,
        range = h.node_range(comment_node),
      }
    end
  end

  local containers_by_key = {}
  for _, c in ipairs(containers) do
    containers_by_key[c.node_key] = c
  end

  return containers, entries, comments, containers_by_key
end

local function find_container_for_node(containers_by_key, node)
  return containers_by_key[h.node_id_key(node)]
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
      sort_key = h.normalize_element_text(vim.treesitter.get_node_text(field_node, bufnr)),
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

-- ─── build_outline ────────────────────────────────────────────────────────────

local function build_outline(container, ctx)
  local raw = ctx.entries_by_parent[container.node_key] or {}
  local sorted_raw = h.sort_entries_by_position(raw)

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
  if not h.capability_allows(kind, ctx.options) then
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

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_parent[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  return {
    kind = kind,
    range = container.range,
    structural_separator = ctx.options.structural_separator,
    trailing_separator_allowed = ctx.options.trailing_separator_allowed == true,
    entries = outline_entries,
  }
end

---@param bufnr integer
---@param target table
---@param config { filetype: string, query_text: string, options: table }
---@return table|nil
function M.build(bufnr, target, config)
  if not h.validate_options(config.options) then
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

  local chosen = h.pick_innermost(containers, target)
  if not chosen then
    return nil
  end

  local ctx = {
    bufnr = bufnr,
    options = config.options,
    containers_by_key = containers_by_key,
    entries_by_parent = h.index_by_parent(entries),
    comments_by_parent = h.index_by_parent(comments),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  lua = "lua",
}

return M
