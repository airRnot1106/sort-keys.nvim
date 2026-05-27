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

local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")
local container_pick = require("sort-keys.core.container_pick")

local M = {}

local CAPTURE = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  comment = "sortkeys.comment",
}

local META = {
  kind = "sortkeys.kind",
  entry_kind = "sortkeys.entry_kind",
}

-- The synthetic key under which root-level pair entries live in
-- entries_by_parent. The real document node's node_id_key is also computed
-- but never used because the document range covers the whole file and
-- collide-by-area logic would pull every cursor into it; we attach root
-- entries to this dedicated key instead.
local ROOT_PSEUDO_KEY = "toml-root-pseudo"

local function node_range(node)
  local sr, sc, er, ec = node:range()
  return { sr, sc, er, ec }
end

local function node_id_key(node)
  local sr, sc, er, ec = node:range()
  return string.format("%s:%d:%d:%d:%d", node:type(), sr, sc, er, ec)
end

local function pos_inside(range, row, col)
  local sr, sc, er, ec = range[1], range[2], range[3], range[4]
  if row < sr or row > er then
    return false
  end
  if row == sr and col < sc then
    return false
  end
  if row == er and col > ec then
    return false
  end
  return true
end

local function contains_range(outer, inner)
  return pos_inside(outer, inner[1], inner[2]) and pos_inside(outer, inner[3], inner[4])
end

local function range_area(r)
  return (r[3] - r[1]) * 1000000 + (r[4] - r[2])
end

local function pick_innermost(containers, target)
  if target.kind == "cursor" then
    return container_pick.for_cursor(containers, target.pos)
  end
  local candidates = {}
  for _, c in ipairs(containers) do
    if contains_range(c.range, target.range) then
      candidates[#candidates + 1] = c
    end
  end
  if #candidates == 0 then
    return nil
  end
  table.sort(candidates, function(a, b)
    return range_area(a.range) < range_area(b.range)
  end)
  return candidates[1]
end

local function normalize_element_text(text)
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  return (trimmed:gsub("%s+", " "))
end

-- tree-sitter-toml routinely reports the last `table` / `table_array_element`
-- range one row past the buffer's last actual line (a phantom trailing
-- newline the grammar assumes). The applier feeds outline.range straight to
-- `nvim_buf_get_text`, which errors on out-of-bounds rows, so clamp before
-- returning. Same fix pattern as yaml_builder.
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

-- ─── query traversal ──────────────────────────────────────────────────────────

local function collect_matches(bufnr, root, query)
  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local containers = {}
  local entry_candidates = {}
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

  for _, match, metadata in query:iter_matches(root, bufnr, 0, -1, { all = true }) do
    local container_node = first_node(match, CAPTURE.container)
    if container_node then
      local kind = metadata[META.kind]
      if kind then
        containers[#containers + 1] = {
          node = container_node,
          range = node_range(container_node),
          kind = kind,
          node_key = node_id_key(container_node),
        }
      end
    end

    local entry_node = first_node(match, CAPTURE.entry)
    if entry_node then
      local entry_kind = metadata[META.entry_kind]
      if entry_kind then
        entry_candidates[#entry_candidates + 1] = {
          node = entry_node,
          range = node_range(entry_node),
          entry_kind = entry_kind,
        }
      end
    end

    local comment_node = first_node(match, CAPTURE.comment)
    if comment_node then
      comments[#comments + 1] = {
        node = comment_node,
        range = node_range(comment_node),
      }
    end
  end

  -- The array element query is a wildcard `(array (_) @sortkeys.entry)` so
  -- comment siblings of the array are also captured as entries. Drop any
  -- candidate whose node was also captured as a comment, otherwise it would
  -- be sorted as data AND attached as a comment, and comment_attach's
  -- expansion could push a real entry past it on the same row — making the
  -- applier crash on an out-of-order inter-entry gap.
  local comment_ids = {}
  for _, c in ipairs(comments) do
    comment_ids[node_id_key(c.node)] = true
  end
  local entries = {}
  for _, e in ipairs(entry_candidates) do
    if not comment_ids[node_id_key(e.node)] then
      entries[#entries + 1] = e
    end
  end

  return containers, entries, comments
end

-- Index by parent node_key for pair / element entries. Pair entries whose
-- parent is the document node land under that document key — the
-- synthesize_root_pseudo step below remaps them to ROOT_PSEUDO_KEY.
local function index_entries_by_parent(entries)
  local by_parent = {}
  for _, item in ipairs(entries) do
    local parent = item.node:parent()
    if parent then
      local pk = node_id_key(parent)
      by_parent[pk] = by_parent[pk] or {}
      by_parent[pk][#by_parent[pk] + 1] = item
    end
  end
  return by_parent
end

local function index_comments_by_parent(comments)
  local by_parent = {}
  for _, item in ipairs(comments) do
    local parent = item.node:parent()
    if parent then
      local pk = node_id_key(parent)
      by_parent[pk] = by_parent[pk] or {}
      by_parent[pk][#by_parent[pk] + 1] = item
    end
  end
  return by_parent
end

-- A `document` ranges over the whole file, so adding it directly to
-- `containers` would swallow every cursor. Instead, we synthesize a
-- pseudo-container whose range is exactly (first_root_pair.start ..
-- last_root_pair.end). The pseudo-container only appears when ≥2 root pairs
-- exist (a single root pair is not sortable, and we don't want to outshine
-- a more-specific child container for the same row).
local function synthesize_root_pseudo(root, entries_by_parent, comments_by_parent)
  local root_key = node_id_key(root)
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
  return containers_by_key[node_id_key(node)]
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
      entry.sort_key = normalize_element_text(vim.treesitter.get_node_text(e.node, ctx.bufnr))
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

local function validate_options(options)
  local required = {
    "can_sort_object",
    "can_sort_array",
    "can_deep",
    "key_quoting",
  }
  for _, k in ipairs(required) do
    if options[k] == nil then
      return false
    end
  end
  return true
end

---@param bufnr integer
---@param target table
---@param config { filetype: string, query_text: string, options: table }
---@return table|nil
function M.build(bufnr, target, config)
  if not validate_options(config.options) then
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

  local containers, entries, comments = collect_matches(bufnr, root, query)

  local entries_by_parent = index_entries_by_parent(entries)
  local comments_by_parent = index_comments_by_parent(comments)

  local root_pseudo = synthesize_root_pseudo(root, entries_by_parent, comments_by_parent)
  if root_pseudo then
    containers[#containers + 1] = root_pseudo
  end

  if #containers == 0 then
    return nil
  end

  local chosen = pick_innermost(containers, target)
  if not chosen then
    return nil
  end

  local containers_by_key = {}
  for _, c in ipairs(containers) do
    containers_by_key[c.node_key] = c
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
