-- KDL builder.
--
-- KDL is a document tree of named `node`s. The two sortable containers are:
--   * `document`      — the file root; its top-level `node` children are the
--                       document-level entries.
--   * `node_children` — a `{ ... }` block hung off a node; its `node`
--                       children are that node's sub-entries.
-- Both are object-like: each entry is a `node` keyed by its name (the node's
-- `identifier`), so there is no object-vs-array vote. KDL has no sortable
-- array shape — positional node arguments are order-significant by spec and
-- are never reordered; they ride inside their owning node's range.
--
-- One KDL-specific wrinkle drives the trailing-newline trim below: the grammar
-- folds a node's terminator (the newline / `;`) INTO the node, so a node's
-- range ends at column 0 of the following row. core/comment_attach's
-- same-line-trailing rule keys off `prev_entry_end_row == comment_start_row`;
-- the absorbed newline inflates that end row by one and would misread a
-- standalone leading comment as a trailing comment of the previous node. We
-- trim the phantom newline so each entry ends at its real content, matching
-- the convention the policy layer assumes.

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

local CAPTURE = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  comment = "sortkeys.comment",
}

-- Drop the node-terminating newline a KDL node range absorbs so the entry
-- ends at its real content (see the file header). A node range ending at
-- column 0 of a later row means the content ends at the end of the previous
-- row; step back to it. Ranges that already end mid-row (e.g. `;`-separated
-- nodes on one line) are returned untouched.
local function trim_trailing_newline(bufnr, range)
  local sr, sc, er, ec = range[1], range[2], range[3], range[4]
  if ec == 0 and er > sr then
    er = er - 1
    local line = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or ""
    ec = #line
  end
  return { sr, sc, er, ec }
end

local function first_child_of_type(node, type_name)
  for child in node:iter_children() do
    if child:type() == type_name then
      return child
    end
  end
  return nil
end

-- ─── query traversal (local — KDL clamps container ranges and skips
--                     sortkeys.kind / sortkeys.entry_kind metadata) ───────────

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
      -- Kind is always object-like for KDL, so containers are added
      -- unconditionally (no sortkeys.kind metadata guard). node_key stays the
      -- raw node identity; only the applier-facing range is clamped so the
      -- document's phantom trailing row never reaches nvim_buf_get_text.
      containers[#containers + 1] = {
        node = container_node,
        range = h.clamp_range_to_buffer(bufnr, h.node_range(container_node)),
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

-- A node's sort_key is its name: the first direct `identifier` child (after an
-- optional `node_comment` `/-` and an optional `(type)` annotation, neither of
-- which is an `identifier` node, so the node name is unambiguous).
local function node_sort_key(node, bufnr)
  local name = first_child_of_type(node, "identifier")
  if not name then
    return ""
  end
  return key_normalize.kdl(vim.treesitter.get_node_text(name, bufnr))
end

-- ─── build_outline ────────────────────────────────────────────────────────────

local function build_outline(container, ctx)
  -- KDL has no array-shaped container (positional node args are
  -- order-significant); only `can_sort_object` is consulted.
  if not h.capability_allows("object", ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_parent[container.node_key] or {}
  local sorted_raw = h.sort_entries_by_position(raw)

  local outline_entries = {}
  for i, e in ipairs(sorted_raw) do
    local entry = {
      kind = "pair",
      range = trim_trailing_newline(ctx.bufnr, e.range),
      sort_key = node_sort_key(e.node, ctx.bufnr),
      movable = true,
      anchor = i,
      attached = {},
      child = nil,
    }

    local children = first_child_of_type(e.node, "node_children")
    if children then
      local inner = ctx.containers_by_key[h.node_id_key(children)]
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
    kind = "object",
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
  kdl = "kdl",
}

return M
