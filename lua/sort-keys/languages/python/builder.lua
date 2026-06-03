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

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

local function find_container_for_node(containers_by_key, node)
  return containers_by_key[h.node_id_key(node)]
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
    return { sort_key = h.normalize_element_text(text), movable = false }
  end
  -- Unknown / future key shape: keep order, sort_key from surface text so the
  -- entry still has something printable in case the user introspects.
  return { sort_key = h.normalize_element_text(text), movable = false }
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

-- ─── build_outline ────────────────────────────────────────────────────────────

local function build_outline(container, ctx)
  if not h.capability_allows(container.kind, ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_parent[container.node_key] or {}
  local sorted_raw = h.sort_entries_by_position(raw)

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
        entry.sort_key = h.normalize_element_text(vim.treesitter.get_node_text(e.node, ctx.bufnr))
        entry.movable = false
      else
        entry.sort_key = h.normalize_element_text(vim.treesitter.get_node_text(e.node, ctx.bufnr))
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

  local containers, entries, comments, containers_by_key = h.collect_matches(bufnr, root, query)
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
  python = "python",
}

return M
