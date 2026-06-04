-- Elixir builder.
--
-- Two sortable container shapes, both key-keyed:
--   map  (`%{...}` / `%Struct{...}`) — atom-shorthand `k: v` pairs and arrow
--        `k => v` binary operators
--   keyword list (`[k: v]`) — a `list` that holds a `keywords` child
--
-- Like Nix, the AST interposes a node between the container and its entries:
-- a map nests `map_content` > `keywords` > `pair`, and a keyword list nests
-- `keywords` > `pair`, so `entry:parent()` never lands on the captured
-- container. Comments are one level higher still — they hang off the
-- enclosing `map` / `list`, a sibling of `map_content`. Both entries and
-- comments are therefore resolved to their nearest captured container
-- ancestor, which lands them under the same key for comment_attach.

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.languages.elixir.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

-- Resolve each item (entry or comment) to its nearest captured container
-- ancestor by walking `node:parent()` upward until a captured node is hit.
local function index_by_container_ancestor(items, containers_by_key)
  local by_key = {}
  for _, item in ipairs(items) do
    local cur = item.node:parent()
    while cur do
      local key = h.node_id_key(cur)
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
  return containers_by_key[h.node_id_key(node)]
end

-- ─── build_outline ────────────────────────────────────────────────────────────

local function build_outline(container, ctx)
  if not h.capability_allows(container.kind, ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_container[container.node_key] or {}
  local sorted_raw = h.sort_entries_by_position(raw)

  local outline_entries = {}
  for i, e in ipairs(sorted_raw) do
    -- A captured entry always carries its key node (the query requires it);
    -- the defensive branch keeps a malformed match from crashing the sort.
    local sort_key, movable = "", false
    if e.key_node then
      sort_key = ctx.key_normalizer(vim.treesitter.get_node_text(e.key_node, ctx.bufnr))
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

    -- The value subtree may itself be a sortable map / keyword list.
    local inner = find_container_for_node(ctx.containers_by_key, e.value_node)
    if inner and inner.node_key ~= container.node_key then
      entry.child = build_outline(inner, ctx)
    end

    outline_entries[#outline_entries + 1] = entry
  end

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_container[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  local sep, trailing = h.separator_for(container, ctx.options)
  return {
    kind = container.kind,
    range = container.range,
    structural_separator = sep,
    trailing_separator_allowed = trailing,
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
    entries_by_container = index_by_container_ancestor(entries, containers_by_key),
    comments_by_container = index_by_container_ancestor(comments, containers_by_key),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  elixir = "elixir",
}

-- Self-declared default normalizer; the registry injects this (or a
-- user override) as config.key_normalizer.
M.key_normalizer = key_normalize

return M
