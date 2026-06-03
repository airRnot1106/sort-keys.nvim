-- Nix builder.
--
-- Nix has six sortable container shapes (attrset, rec attrset, let,
-- list, formals, inherited_attrs) with three different separator policies
-- (`;`, `,`, whitespace), plus two AST quirks the other builders don't hit:
--
--   1. attrset / rec_attrset / let interpose a `binding_set` node between
--      the container and its bindings. Walking `entry:parent()` lands on
--      `binding_set` instead of the container, so this builder resolves
--      each entry to its nearest container ancestor.
--   2. `inherit` / `inherit_from` is one entry from the outer perspective
--      (the binding itself is pinned, by user policy) but exposes its
--      `inherited_attrs` child as another container so the identifier
--      order inside `inherit a c b;` can still sort.

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

-- Index entries by their *nearest container ancestor*. This is the variant
-- needed for Nix because attrset / rec_attrset / let wrap their bindings in
-- a `binding_set` node, so a flat parent() check would not reach the
-- container.
local function index_by_container_ancestor(entries, containers_by_key)
  local by_key = {}
  for _, item in ipairs(entries) do
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

local function index_comments_by_container_ancestor(comments, containers_by_key)
  local by_key = {}
  for _, item in ipairs(comments) do
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

-- ─── per-container separator policy ───────────────────────────────────────────

-- Nix attrset / rec_attrset / let bindings end in `;` (every binding,
-- including the last, has a trailing semicolon). Formals use `,` between
-- entries; a trailing `,` after the last formal is a syntax error and
-- inserting one would corrupt the file. list_expression and inherited_attrs
-- are whitespace-gapped, so an empty separator lets the buffer gap carry
-- the spacing.
local function separator_for_container_node_type(node_type)
  if
    node_type == "attrset_expression"
    or node_type == "rec_attrset_expression"
    or node_type == "let_expression"
  then
    return ";", true
  end
  if node_type == "formals" then
    return ",", false
  end
  return "", true
end

-- ─── Nix entry classification ─────────────────────────────────────────────────

-- Return the first identifier text inside an `inherit` / `inherit_from`
-- node's `inherited_attrs`. Used as the entry's sort_key — even though the
-- entry is pinned (movable=false), a sort_key keeps Outline contract happy
-- and the value is stable across runs since the identifier order can only
-- change via the inner sort.
local function first_inherited_identifier_text(inherit_node, bufnr)
  local attrs = h.first_child_of_type(inherit_node, "inherited_attrs")
  if not attrs then
    return ""
  end
  local first_id = attrs:named_child(0)
  if not first_id then
    return ""
  end
  return vim.treesitter.get_node_text(first_id, bufnr)
end

local function classify_entry(entry_node, bufnr)
  local t = entry_node:type()

  if t == "binding" then
    local attrpath = h.first_child_of_type(entry_node, "attrpath")
    if not attrpath then
      return { sort_key = "", movable = false, value_node = nil }
    end
    local key_text = vim.treesitter.get_node_text(attrpath, bufnr)
    return {
      sort_key = key_normalize.nix(key_text),
      movable = true,
      -- The value subtree may itself contain a sortable container.
      value_node = entry_node:named_child(entry_node:named_child_count() - 1),
    }
  end

  if t == "inherit" or t == "inherit_from" then
    -- The binding pins by user policy; the inner identifier list sorts via
    -- the inherit / inherit_from node *itself* exposed as an array
    -- container, so the cursor on `inherit` / `(expr)` resolves to that
    -- container instead of falling through to the outer attrset.
    return {
      sort_key = first_inherited_identifier_text(entry_node, bufnr),
      movable = false,
      value_node = entry_node,
    }
  end

  if t == "formal" then
    -- A formal is `identifier` or `identifier ? default_expr`; named_child(0)
    -- is always the identifier.
    local id = entry_node:named_child(0)
    if not id then
      return { sort_key = "", movable = false, value_node = nil }
    end
    return {
      sort_key = key_normalize.nix(vim.treesitter.get_node_text(id, bufnr)),
      movable = true,
      value_node = nil,
    }
  end

  if t == "ellipses" then
    -- Nix grammar forces `...` to be the last formal; pinning preserves
    -- that even when surrounding formals reorder.
    return { sort_key = "...", movable = false, value_node = nil }
  end

  if t == "identifier" then
    return {
      sort_key = key_normalize.nix(vim.treesitter.get_node_text(entry_node, bufnr)),
      movable = true,
      value_node = nil,
    }
  end

  -- Generic list element (variable_expression / integer_expression / etc.).
  return {
    sort_key = h.normalize_element_text(vim.treesitter.get_node_text(entry_node, bufnr)),
    movable = true,
    value_node = entry_node,
  }
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
    local cls = classify_entry(e.node, ctx.bufnr)
    local entry = {
      kind = e.entry_kind,
      range = e.range,
      sort_key = cls.sort_key,
      movable = cls.movable,
      anchor = i,
      attached = {},
      child = nil,
    }

    if cls.value_node then
      local inner = find_container_for_node(ctx.containers_by_key, cls.value_node)
      if inner then
        entry.child = build_outline(inner, ctx)
      end
    end

    outline_entries[#outline_entries + 1] = entry
  end

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_container[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  local sep, trailing = separator_for_container_node_type(container.node:type())

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
    entries_by_container = index_by_container_ancestor(entries, containers_by_key),
    comments_by_container = index_comments_by_container_ancestor(comments, containers_by_key),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  nix = "nix",
}

return M
