-- JavaScript builder.
--
-- JS objects mix several entry kinds (regular pairs, shorthand identifiers,
-- spreads, methods, computed-key pairs); some are sortable, some must stay
-- in place. The query captures every direct child of `object` as an entry
-- and this module decides each entry's `sort_key` + `movable` according to
-- its AST shape.

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.languages.javascript.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

local function find_container_for_node(containers_by_key, node)
  return containers_by_key[h.node_id_key(node)]
end

-- ─── JS-specific entry classification ─────────────────────────────────────────

-- Sort decisions per entry shape:
--   pair                          → key from named_child(0); movable depends on key node type
--   shorthand_property_identifier → identifier text as sort_key; movable
--   method_definition             → method's property_identifier as sort_key; movable
--   spread_element                → movable=false (spread order is semantically significant)
-- A pair whose key is a computed_property_name is also pinned (the key is a
-- runtime expression; reordering it past sibling pairs may change semantics).
local function classify_entry(entry_node, bufnr, normalize)
  local t = entry_node:type()

  if t == "shorthand_property_identifier" then
    return { sort_key = vim.treesitter.get_node_text(entry_node, bufnr), movable = true }
  end

  if t == "spread_element" then
    -- A spread is order-sensitive: a later key overrides an earlier one, so it
    -- fences the sort — surrounding pairs may not reorder across it.
    return { sort_key = "", movable = false, fence = true }
  end

  if t == "method_definition" then
    for child in entry_node:iter_children() do
      if child:type() == "property_identifier" then
        return { sort_key = vim.treesitter.get_node_text(child, bufnr), movable = true }
      end
    end
    return { sort_key = "", movable = false }
  end

  if t == "pair" then
    local key_node = entry_node:named_child(0)
    if not key_node then
      return { sort_key = "", movable = false }
    end
    local key_type = key_node:type()
    if key_type == "computed_property_name" then
      -- A computed key is a runtime expression; its evaluation order relative
      -- to siblings can matter, so it fences the sort like a spread.
      return { sort_key = "", movable = false, fence = true }
    end
    if key_type == "property_identifier" or key_type == "number" then
      return { sort_key = vim.treesitter.get_node_text(key_node, bufnr), movable = true }
    end
    if key_type == "string" then
      return {
        sort_key = normalize(vim.treesitter.get_node_text(key_node, bufnr)),
        movable = true,
      }
    end
    -- template_string or any other key node form: don't pretend we can sort.
    return { sort_key = "", movable = false }
  end

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
      local cls = classify_entry(e.node, ctx.bufnr, ctx.key_normalizer)
      if cls then
        entry.sort_key = cls.sort_key
        entry.movable = cls.movable
        entry.fence = cls.fence
      else
        entry.sort_key = ""
        entry.movable = false
      end

      if e.node:type() == "pair" then
        local value_node = e.node:named_child(1)
        if value_node then
          local inner = find_container_for_node(ctx.containers_by_key, value_node)
          if inner then
            entry.child = build_outline(inner, ctx)
          end
        end
      end
    else
      local elem_text = vim.treesitter.get_node_text(e.node, ctx.bufnr)
      entry.sort_key = h.normalize_element_text(elem_text)
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
    key_normalizer = config.key_normalizer or key_normalize,
    containers_by_key = containers_by_key,
    entries_by_parent = h.index_by_parent(entries),
    comments_by_parent = h.index_by_parent(comments),
  }

  return build_outline(chosen, ctx)
end

-- tree-sitter-typescript inherits the object / pair / array / spread_element /
-- method_definition / property_identifier node names from tree-sitter-javascript,
-- so the JS classify_entry logic applies as-is to TS object/array literals.
-- TS-specific nodes (type_annotation, as_expression, generic_type) appear
-- outside the key position or inside the value subtree and are transparent.
M.filetypes = {
  javascript = "javascript",
  typescript = "typescript",
}

-- Self-declared default normalizer; the registry injects this (or a
-- user override) as config.key_normalizer.
M.key_normalizer = key_normalize

return M
