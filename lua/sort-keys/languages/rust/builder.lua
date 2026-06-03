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

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

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
  local direct = containers_by_key[h.node_id_key(node)]
  if direct then
    return direct
  end
  for child in node:iter_children() do
    local c = containers_by_key[h.node_id_key(child)]
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

-- ─── build_outline ────────────────────────────────────────────────────────────

local function build_outline(container, ctx)
  if not h.capability_allows(container.kind, ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_parent[container.node_key] or {}
  local sorted_raw = h.sort_entries_by_position(raw)

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
  rust = "rust",
}

return M
