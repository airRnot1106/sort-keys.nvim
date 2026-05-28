-- Pkl builder.
--
-- Pkl exposes two sortable container shapes:
--   * `module`     — the file root; its `classProperty` children are the
--                    top-level properties (always keyed → object-like).
--   * `objectBody` — a `{ ... }` block that can be a property block
--                    (`objectProperty`), a mapping (`objectEntry`,
--                    `["k"] = v`), or a listing (`objectElement`, a bare
--                    value). The kind is not knowable from the node type,
--                    so it is voted on after collecting the entries — any
--                    keyed entry makes the body object-like; all-element
--                    bodies are arrays. This mirrors lua's table_constructor.
--
-- Entries sit as DIRECT children of their container (no interposed node like
-- Nix's binding_set), so a flat parent() index suffices. Pkl separates
-- entries by newline/whitespace rather than a punctuation token, so the
-- structural separator is empty and the buffer gaps carry the spacing.

local key_normalize = require("sort-keys.strategies.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")
local container_pick = require("sort-keys.core.container_pick")

local M = {}

local CAPTURE = {
  container = "sortkeys.container",
  entry = "sortkeys.entry",
  comment = "sortkeys.comment",
}

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

-- The `module` node spans the whole file and ends one row past the buffer's
-- last actual line (the phantom trailing newline the grammar assumes). The
-- applier feeds outline.range straight to `nvim_buf_get_text`, which errors
-- on out-of-bounds rows, so clamp the container range to real buffer bounds.
-- objectBody ranges sit within `{ }` and are unaffected. Same fix pattern as
-- toml_builder / yaml_builder.
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
      -- Kind is computed in build_outline, so containers are added
      -- unconditionally (no sortkeys.kind metadata guard). node_key stays the
      -- raw node identity; only the applier-facing range is clamped so the
      -- module's phantom trailing row never reaches nvim_buf_get_text.
      containers[#containers + 1] = {
        node = container_node,
        range = clamp_range_to_buffer(bufnr, node_range(container_node)),
        node_key = node_id_key(container_node),
      }
    end

    local entry_node = first_node(match, CAPTURE.entry)
    if entry_node then
      entries[#entries + 1] = {
        node = entry_node,
        range = node_range(entry_node),
      }
    end

    local comment_node = first_node(match, CAPTURE.comment)
    if comment_node then
      comments[#comments + 1] = {
        node = comment_node,
        range = node_range(comment_node),
      }
    end
  end

  return containers, entries, comments
end

local function index_by_parent(items)
  local by_parent = {}
  for _, item in ipairs(items) do
    local parent = item.node:parent()
    if parent then
      local pk = node_id_key(parent)
      by_parent[pk] = by_parent[pk] or {}
      by_parent[pk][#by_parent[pk] + 1] = item
    end
  end
  return by_parent
end

local function first_field(node, name)
  local found = node:field(name)
  return found and found[1] or nil
end

local function last_named_child(node)
  local n = node:named_child_count()
  if n == 0 then
    return nil
  end
  return node:named_child(n - 1)
end

-- The container that a value subtree opens, if any. A direct `objectBody`
-- is the body itself; a `new X { ... }` / amends wraps the body one level
-- down, so scan the value's immediate children for it.
local function body_container(value_node, containers_by_key)
  if not value_node then
    return nil
  end
  if value_node:type() == "objectBody" then
    return containers_by_key[node_id_key(value_node)]
  end
  for child in value_node:iter_children() do
    if child:type() == "objectBody" then
      return containers_by_key[node_id_key(child)]
    end
  end
  return nil
end

-- ─── Pkl entry classification ─────────────────────────────────────────────────

-- Maps a Pkl entry node to its sort_key, kind vote, and the value subtree to
-- recurse into for :DeepSortKeys.
--   classProperty / objectProperty — `identifier = value` or `identifier { }`;
--                                     key is the identifier, value the last
--                                     named child.
--   objectEntry                    — `[key] = valueExpr`; key/value are fields.
--   objectElement                  — a bare listing value; the element itself
--                                     is the value, sorted by surface text.
local function classify_entry(node, bufnr)
  local t = node:type()

  if t == "classProperty" or t == "objectProperty" then
    local id = node:named_child(0)
    local key_text = id and vim.treesitter.get_node_text(id, bufnr) or ""
    return {
      sort_key = key_normalize.pkl(key_text),
      movable = true,
      kind_vote = "object",
      value_node = last_named_child(node),
    }
  end

  if t == "objectEntry" then
    local key = first_field(node, "key")
    local key_text = key and vim.treesitter.get_node_text(key, bufnr) or ""
    return {
      sort_key = key_normalize.pkl(key_text),
      movable = true,
      kind_vote = "object",
      value_node = first_field(node, "valueExpr"),
    }
  end

  if t == "objectElement" then
    return {
      sort_key = normalize_element_text(vim.treesitter.get_node_text(node, bufnr)),
      movable = true,
      kind_vote = "array",
      value_node = node:named_child(0),
    }
  end

  return { sort_key = "", movable = false, kind_vote = "object", value_node = nil }
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
  local votes_object = 0
  local classifications = {}
  for i, e in ipairs(sorted_raw) do
    local cls = classify_entry(e.node, ctx.bufnr)
    classifications[i] = cls
    if cls.kind_vote == "object" then
      votes_object = votes_object + 1
    end

    local entry = {
      kind = "pair",
      range = e.range,
      sort_key = cls.sort_key,
      movable = cls.movable,
      anchor = i,
      attached = {},
      child = nil,
    }

    local inner = body_container(cls.value_node, ctx.containers_by_key)
    if inner then
      entry.child = build_outline(inner, ctx)
    end

    outline_entries[#outline_entries + 1] = entry
  end

  local kind = (votes_object == 0) and "array" or "object"
  if not capability_allows(kind, ctx.options) then
    return nil
  end

  if kind == "array" then
    for i, entry in ipairs(outline_entries) do
      entry.kind = "element"
      entry.movable = true
      entry.sort_key = classifications[i].sort_key
    end
  end

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_parent[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  return {
    kind = kind,
    range = container.range,
    structural_separator = ctx.options.structural_separator,
    trailing_separator_allowed = ctx.options.trailing_separator_allowed == true,
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
    entries_by_parent = index_by_parent(entries),
    comments_by_parent = index_by_parent(comments),
  }

  return build_outline(chosen, ctx)
end

M.filetypes = {
  pkl = "pkl",
}

return M
