-- TOML builder.
--
-- TOML has its own container zoo: `inline_table` / `array` (comma-separated),
-- `table` / `table_array_element` (newline-separated, no inline comma), and
-- the document-direct pair group (likewise newline-separated). The grammar
-- gives no node that *only* covers the document-direct pairs, so this
-- builder synthesizes a pseudo-container for them when ≥2 root-level pairs
-- exist (`# comment` and `[section]` siblings naturally fall outside).
--
-- Lua / YAML are the closest precedents — same outline shape, same
-- comment_attach delegation, same per-container separator policy.

local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

-- The synthetic key under which root-level pair entries live in
-- entries_by_parent. The real document node's node_id_key is also computed
-- but never used because the document range covers the whole file and
-- collide-by-area logic would pull every cursor into it; we attach root
-- entries to this dedicated key instead.
local ROOT_PSEUDO_KEY = "toml-root-pseudo"

local function clamp_range_to_buffer(bufnr, range)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local sr, sc, er, ec = range[1], range[2], range[3], range[4]
  if er > line_count - 1 then
    er = line_count - 1
    local last_line = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or ""
    ec = #last_line
  else
    local row_line = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or ""
    if ec > #row_line then
      ec = #row_line
    end
  end
  return { sr, sc, er, ec }
end

-- A `document` ranges over the whole file, so adding it directly to
-- `containers` would swallow every cursor. Instead, we synthesize a
-- pseudo-container whose range is exactly (first_root_pair.start ..
-- last_root_pair.end). The pseudo-container only appears when ≥2 root pairs
-- exist (a single root pair is not sortable, and we don't want to outshine
-- a more-specific child container for the same row).
local function synthesize_root_pseudo(root, entries_by_parent, comments_by_parent)
  local root_key = h.node_id_key(root)
  local root_pairs = entries_by_parent[root_key]
  if not root_pairs or #root_pairs < 2 then
    return nil
  end
  -- Only `pair` entry_kind belongs at document level; defensively filter.
  local pair_entries = {}
  for _, e in ipairs(root_pairs) do
    if e.entry_kind == "pair" then
      pair_entries[#pair_entries + 1] = e
    end
  end
  if #pair_entries < 2 then
    return nil
  end
  table.sort(pair_entries, function(a, b)
    if a.range[1] ~= b.range[1] then
      return a.range[1] < b.range[1]
    end
    return a.range[2] < b.range[2]
  end)
  local first = pair_entries[1]
  local last = pair_entries[#pair_entries]
  local range = { first.range[1], first.range[2], last.range[3], last.range[4] }

  entries_by_parent[ROOT_PSEUDO_KEY] = pair_entries
  entries_by_parent[root_key] = nil

  -- Move comments whose parent is the document onto the pseudo container too
  -- (so comment_attach can run inside this pseudo container). Comments that
  -- live outside the root pair span (e.g. comments above the first root
  -- pair) are still preserved by the buffer prefix at apply time.
  local root_comments = comments_by_parent[root_key]
  if root_comments then
    local within = {}
    for _, c in ipairs(root_comments) do
      if c.range[1] >= range[1] and c.range[3] <= range[3] then
        within[#within + 1] = c
      end
    end
    comments_by_parent[ROOT_PSEUDO_KEY] = within
  end

  return {
    node = root,
    range = range,
    kind = "object",
    node_key = ROOT_PSEUDO_KEY,
  }
end

local function find_container_for_node(containers_by_key, node)
  return containers_by_key[h.node_id_key(node)]
end

-- ─── TOML entry / key extraction ──────────────────────────────────────────────

-- TOML's `pair` shape: key (bare_key / quoted_key / dotted_key) -> `=` -> value.
-- `named_child(0)` is the key, `named_child(1)` is the value. dotted keys
-- arrive as a single `dotted_key` node whose text contains the dots; we let
-- key_normalize.toml emit "a.b.c" verbatim so the whole path becomes the
-- sort_key.
local function key_sort_for_pair(pair_node, bufnr)
  local key_node = pair_node:named_child(0)
  if not key_node then
    return "", false
  end
  local key_text = vim.treesitter.get_node_text(key_node, bufnr)
  return key_normalize.toml(key_text), true
end

-- ─── per-container separator policy ───────────────────────────────────────────

-- inline_table / array carry a literal `,` between entries; standard table,
-- [[array_of_tables]] block, and the document pseudo carry their separation
-- in the buffer gap (newline + indent) and want no inline separator at all.
-- TOML 1.0 forbids a trailing comma inside `inline_table` but allows one
-- inside `array`, so we encode that distinction here.
local function separator_for_container_node_type(node_type)
  if node_type == "inline_table" then
    return ",", false
  end
  if node_type == "array" then
    return ",", true
  end
  return "", true
end

local function separator_for_container(container)
  if container.node_key == ROOT_PSEUDO_KEY then
    return "", true
  end
  return separator_for_container_node_type(container.node:type())
end

-- ─── capability + build_outline ───────────────────────────────────────────────

local function capability_allows(kind, options)
  if kind == "object" then
    return options.can_sort_object == true
  end
  if kind == "array" then
    return options.can_sort_array == true
  end
  return false
end

local function build_outline(container, ctx)
  if not capability_allows(container.kind, ctx.options) then
    return nil
  end

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
  for i, e in ipairs(sorted_raw) do
    local entry = {
      kind = e.entry_kind,
      range = clamp_range_to_buffer(ctx.bufnr, e.range),
      movable = true,
      anchor = i,
      attached = {},
      child = nil,
    }

    if e.entry_kind == "pair" then
      local sort_key, ok = key_sort_for_pair(e.node, ctx.bufnr)
      entry.sort_key = sort_key
      entry.movable = ok
      local value_node = e.node:named_child(1)
      if value_node then
        local inner = find_container_for_node(ctx.containers_by_key, value_node)
        if inner then
          entry.child = build_outline(inner, ctx)
        end
      end
    else
      entry.sort_key = h.normalize_element_text(vim.treesitter.get_node_text(e.node, ctx.bufnr))
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

  local sep, trailing = separator_for_container(container)
  local outline_range = clamp_range_to_buffer(ctx.bufnr, container.range)

  -- A leading sibling comment may pull the first entry's range above the
  -- container's own start; extend the outline range so the applier always
  -- has prefix/suffix it can cleanly slice.
  for _, e in ipairs(outline_entries) do
    local er = e.range
    if er[1] < outline_range[1] or (er[1] == outline_range[1] and er[2] < outline_range[2]) then
      outline_range[1], outline_range[2] = er[1], er[2]
    end
    if er[3] > outline_range[3] or (er[3] == outline_range[3] and er[4] > outline_range[4]) then
      outline_range[3], outline_range[4] = er[3], er[4]
    end
  end

  return {
    kind = container.kind,
    range = outline_range,
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

  local entries_by_parent = h.index_by_parent(entries)
  local comments_by_parent = h.index_by_parent(comments)

  local root_pseudo = synthesize_root_pseudo(root, entries_by_parent, comments_by_parent)
  if root_pseudo then
    containers[#containers + 1] = root_pseudo
    containers_by_key[root_pseudo.node_key] = root_pseudo
  end

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
    entries_by_parent = entries_by_parent,
    comments_by_parent = comments_by_parent,
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  toml = "toml",
}

return M
