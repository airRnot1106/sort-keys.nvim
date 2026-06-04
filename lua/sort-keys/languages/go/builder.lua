-- Go builder.
--
-- Three sortable container shapes:
--   field_declaration_list (struct definition body)        kind = object
--   literal_value          (struct or map composite body)  kind = object
--   import_spec_list       (parenthesized import group)    kind = array
--
-- The `literal_value` AST is shared with slice / array composite literals,
-- whose entries are positional `literal_element` children rather than
-- `keyed_element`. The query captures `literal_value` unconditionally;
-- M.build then drops any captured container whose direct children include
-- no `keyed_element` so the cursor on a slice / array literal falls
-- through to "no sortable structure under cursor" instead of silently
-- doing nothing on an empty Outline.
--
-- Per-container separator policy is set inside build_outline because Go
-- uses two distinct conventions: composite-literal bodies are `,`-separated
-- (with trailing comma required by gofmt when the close brace is on its
-- own line); struct-definition bodies and import groups are newline-gapped
-- with no inline separator.

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.languages.go.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

-- ─── per-container separator policy ───────────────────────────────────────────

local function separator_for_container_node_type(node_type)
  if node_type == "literal_value" then
    return ",", true
  end
  -- field_declaration_list / import_spec_list: newline-gapped, the buffer
  -- gap carries the spacing and any inline separator would be wrong.
  return "", true
end

-- ─── child-context filters ────────────────────────────────────────────────────

local function literal_value_has_keyed_child(node)
  for child in node:iter_children() do
    if child:type() == "keyed_element" then
      return true
    end
  end
  return false
end

-- ─── Go entry classification ──────────────────────────────────────────────────

-- Reads the first import path encountered inside an `import_spec`. The
-- optional `package_identifier` alias is ignored: gofmt sorts imports by
-- path, not by alias, and respecting that gives users the canonical order.
local function import_path_text(import_spec_node, bufnr)
  for child in import_spec_node:iter_children() do
    local t = child:type()
    if t == "interpreted_string_literal" or t == "raw_string_literal" then
      return vim.treesitter.get_node_text(child, bufnr)
    end
  end
  return ""
end

-- Pull the key node out of a `keyed_element`: its first named child is a
-- `literal_element` whose own first named child is the actual key
-- expression (`identifier` for struct fields, `interpreted_string_literal`
-- / `raw_string_literal` / `int_literal` / etc. for map keys).
local function keyed_element_key_node(keyed_node)
  local wrapper = keyed_node:named_child(0)
  if not wrapper then
    return nil
  end
  return wrapper:named_child(0)
end

-- Pinned key shapes inside a `keyed_element`: a runtime expression as key
-- could change ordering semantics if reordered, so we keep its source
-- position even when surrounding sortable keys reorder.
local PINNED_KEY_TYPES = {
  call_expression = true,
  selector_expression = true,
  index_expression = true,
  binary_expression = true,
  unary_expression = true,
  parenthesized_expression = true,
  type_assertion_expression = true,
}

local function classify_entry(entry, bufnr, normalize)
  local node = entry.node
  local t = node:type()

  if t == "field_declaration" then
    if not entry.key_node then
      return { sort_key = "", movable = false }
    end
    local key_text = vim.treesitter.get_node_text(entry.key_node, bufnr)
    return { sort_key = normalize(key_text), movable = true }
  end

  if t == "keyed_element" then
    local key_node = keyed_element_key_node(node)
    if not key_node then
      return { sort_key = "", movable = false }
    end
    local key_type = key_node:type()
    if PINNED_KEY_TYPES[key_type] then
      return { sort_key = "", movable = false }
    end
    local key_text = vim.treesitter.get_node_text(key_node, bufnr)
    return { sort_key = normalize(key_text), movable = true }
  end

  if t == "import_spec" then
    local path_text = import_path_text(node, bufnr)
    return { sort_key = normalize(path_text), movable = true }
  end

  return { sort_key = "", movable = false }
end

local function inner_container_for(entry, containers_by_key)
  if entry.node:type() ~= "keyed_element" then
    return nil
  end
  -- Value side: keyed_element.named_child(1) is the value's literal_element
  -- wrapper; its first named child is the actual expression.
  local value_wrapper = entry.node:named_child(1)
  if not value_wrapper then
    return nil
  end
  local value_node = value_wrapper:named_child(0)
  return h.find_inner_container_within(containers_by_key, value_node)
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
    local cls = classify_entry(e, ctx.bufnr, ctx.key_normalizer)
    local entry = {
      kind = e.entry_kind,
      range = e.range,
      sort_key = cls.sort_key,
      movable = cls.movable,
      anchor = i,
      attached = {},
      child = nil,
    }

    local inner = inner_container_for(e, ctx.containers_by_key)
    if inner and inner.node_key ~= container.node_key then
      entry.child = build_outline(inner, ctx)
    end

    outline_entries[#outline_entries + 1] = entry
  end

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_parent[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  local sep, trailing = h.separator_for(container, ctx.options, function(c)
    return separator_for_container_node_type(c.node:type())
  end)

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
  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse(lang, config.query_text)

  local containers, entries, comments, containers_by_key = h.collect_matches(bufnr, root, query)

  -- Drop literal_value containers that wrap a slice / array body. The query
  -- captures `literal_value` unconditionally because the Go AST uses the
  -- same node type for struct / map / slice / array bodies; the only
  -- per-shape signal is whether any direct child is a `keyed_element`.
  local function is_sortable_container(c)
    if c.node:type() ~= "literal_value" then
      return true
    end
    return literal_value_has_keyed_child(c.node)
  end
  local kept = {}
  containers_by_key = {}
  for _, c in ipairs(containers) do
    if is_sortable_container(c) then
      kept[#kept + 1] = c
      containers_by_key[c.node_key] = c
    end
  end
  containers = kept

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
  go = "go",
}

-- Self-declared default normalizer; the registry injects this (or a
-- user override) as config.key_normalizer.
M.key_normalizer = key_normalize

return M
