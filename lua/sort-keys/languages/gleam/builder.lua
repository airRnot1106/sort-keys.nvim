-- Gleam builder.
--
-- Four sortable container shapes, all label-keyed:
--   arguments                  (a `record` or `function_call` argument list)
--   data_constructor_arguments (a custom-type constructor's field list)
--   record_update_arguments    (a record-update field list `Pet(..base, x: 1)`)
--   record_pattern_arguments   (a `case` record pattern `Foo(a: x, b: y)`)
--
-- The query captures only lists that hold at least one labelled member, so
-- purely positional calls / tuples / lists never reach here. Within a captured
-- list every member is an entry: a labelled one sorts by its label, a
-- positional one (no `label` field) is pinned so it keeps its slot. Members
-- are direct children of the container, so the shared index_by_parent suffices
-- — no ancestor walk. The inner subtree for :DeepSortKeys is the member's
-- `value` field (arguments) or `pattern` field (record patterns).

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.languages.gleam.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

-- ─── build_outline ────────────────────────────────────────────────────────────

local function build_outline(container, ctx)
  if not h.capability_allows(container.kind, ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_parent[container.node_key] or {}
  local sorted_raw = h.sort_entries_by_position(raw)

  local outline_entries = {}
  for i, e in ipairs(sorted_raw) do
    -- A `label` field marks a labelled argument; its absence marks a
    -- positional argument, which stays put (reordering it would change which
    -- parameter it binds to).
    local label_node = e.node:field("label")[1]
    local sort_key, movable = "", false
    if label_node then
      sort_key = ctx.key_normalizer(vim.treesitter.get_node_text(label_node, ctx.bufnr))
      movable = true
    end

    local entry = {
      kind = e.entry_kind,
      range = e.range,
      sort_key = sort_key,
      movable = movable,
      anchor = i,
      attached = {},
      child = nil,
    }

    -- `value` for argument lists, `pattern` for record patterns: whichever
    -- the member carries is the subtree a nested container hides in.
    local value_node = e.node:field("value")[1] or e.node:field("pattern")[1]
    local inner = h.find_inner_container_within(ctx.containers_by_key, value_node)
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
  local root = parser:parse()[1]:root()

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
    key_normalizer = config.key_normalizer or key_normalize,
    containers_by_key = containers_by_key,
    entries_by_parent = h.index_by_parent(entries),
    comments_by_parent = h.index_by_parent(comments),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  gleam = "gleam",
}

-- Self-declared default normalizer; the registry injects this (or a
-- user override) as config.key_normalizer.
M.key_normalizer = key_normalize

return M
