-- The "parse" stage: buffer + tree-sitter -> IR. This is the generic
-- extractor — it is driven entirely by the pack's `sort-keys.scm` captures and
-- `config.toml`, so a JSON-shaped language needs no per-language Lua.
--
-- Two concerns are handled here so the rest of the pipeline stays oblivious:
--   * comments are folded into per-entry lead/tail via the pure
--     core.comment_fold (only when options.comment_aware)
--   * the inter-entry framing (prefix / separator / joint / trailing / suffix)
--     is OBSERVED from the source as opaque bytes, never configured.
-- render.lua then reproduces everything with one rule.

local comment_fold = require("sort-keys.core.comment_fold")

local M = {}

-- ─── buffer text helpers ──────────────────────────────────────────────────

local function get_text(bufnr, sr, sc, er, ec)
  return table.concat(vim.api.nvim_buf_get_text(bufnr, sr, sc, er, ec, {}), "\n")
end

---String identity for a node, stable across iter_matches calls.
local function node_id_key(node)
  local sr, sc, er, ec = node:range()
  return string.format("%s:%d:%d:%d:%d", node:type(), sr, sc, er, ec)
end

-- ─── target container resolution ──────────────────────────────────────────

local function range_area(r)
  return (r[3] - r[1]) * 1000000 + (r[4] - r[2])
end

local function pos_le(ar, ac, br, bc)
  return ar < br or (ar == br and ac <= bc)
end

local function range_contains_pos(r, row, col)
  if row < r[1] or row > r[3] then
    return false
  end
  if row == r[1] and col < r[2] then
    return false
  end
  if row == r[3] and col > r[4] then
    return false
  end
  return true
end

local function range_covers_range(outer, inner)
  return pos_le(outer[1], outer[2], inner[1], inner[2])
    and pos_le(inner[3], inner[4], outer[3], outer[4])
end

-- Innermost container = smallest-area container that still contains the
-- cursor (or covers the selection range).
local function pick_container(containers, target)
  local best, best_area
  for _, c in ipairs(containers) do
    local ok
    if target.kind == "cursor" then
      ok = range_contains_pos(c.range, target.pos[1], target.pos[2])
    else
      ok = range_covers_range(c.range, target.range)
    end
    if ok then
      local area = range_area(c.range)
      if best_area == nil or area < best_area then
        best, best_area = c, area
      end
    end
  end
  return best
end

-- ─── query traversal ──────────────────────────────────────────────────────

local function collect(bufnr, root, query)
  local cap_id = {}
  for id, name in ipairs(query.captures) do
    cap_id[name] = id
  end

  local function first_node(match, name)
    local id = cap_id[name]
    if not id then
      return nil
    end
    local v = match[id]
    if not v then
      return nil
    end
    -- iter_matches yields a list of nodes per capture on modern Neovim.
    if type(v) == "table" then
      return v[1]
    end
    return v
  end

  local containers = {}
  local containers_by_id = {}
  local raw_entries = {}
  local comments = {}
  local comment_ids = {}
  local seen_entry = {}

  for _, match, metadata in query:iter_matches(root, bufnr, 0, -1) do
    local cnode = first_node(match, "sortkeys.container")
    if cnode and metadata["sortkeys.kind"] then
      local rec = {
        node = cnode,
        range = { cnode:range() },
        kind = metadata["sortkeys.kind"],
      }
      containers[#containers + 1] = rec
      containers_by_id[node_id_key(cnode)] = rec
    end

    local comment_node = first_node(match, "sortkeys.comment")
    if comment_node then
      local parent = comment_node:parent()
      if parent then
        comment_ids[node_id_key(comment_node)] = true
        local pkey = node_id_key(parent)
        comments[pkey] = comments[pkey] or {}
        table.insert(comments[pkey], { node = comment_node, range = { comment_node:range() } })
      end
    end

    local enode = first_node(match, "sortkeys.entry")
    if enode and metadata["sortkeys.entry_kind"] then
      raw_entries[#raw_entries + 1] = {
        node = enode,
        range = { enode:range() },
        entry_kind = metadata["sortkeys.entry_kind"],
        key_node = first_node(match, "sortkeys.key"),
        value_node = first_node(match, "sortkeys.value"),
      }
    end
  end

  -- The wildcard array-element pattern `(array (_) @sortkeys.entry)` also
  -- captures comment children; drop those, and dedup entries captured twice,
  -- so a container never sees two entries with the same range.
  local entries_by_parent = {}
  for _, e in ipairs(raw_entries) do
    local id = node_id_key(e.node)
    if not comment_ids[id] and not seen_entry[id] then
      seen_entry[id] = true
      local parent = e.node:parent()
      if parent then
        local pkey = node_id_key(parent)
        entries_by_parent[pkey] = entries_by_parent[pkey] or {}
        table.insert(entries_by_parent[pkey], e)
      end
    end
  end

  return containers, containers_by_id, entries_by_parent, comments
end

-- ─── outline construction ──────────────────────────────────────────────────

local function capability_allows(kind, options)
  if kind == "object" then
    return options.can_sort_object == true
  end
  if kind == "array" then
    return options.can_sort_array == true
  end
  return false
end

local function build_container(container, ctx)
  if not capability_allows(container.kind, ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_parent[node_id_key(container.node)] or {}
  table.sort(raw, function(a, b)
    if a.range[1] ~= b.range[1] then
      return a.range[1] < b.range[1]
    end
    return a.range[2] < b.range[2]
  end)
  if #raw == 0 then
    return nil
  end

  local container_comments = {}
  if ctx.options.comment_aware then
    container_comments = ctx.comments_by_parent[node_id_key(container.node)] or {}
  end
  local blocks = comment_fold.fold(raw, container_comments)

  -- Separator: the leading non-whitespace run right after the first entry's
  -- DATA (so it is observed even when a trailing comment follows the data).
  local separator = ""
  if #raw >= 2 then
    local probe =
      get_text(ctx.bufnr, raw[1].range[3], raw[1].range[4], raw[2].range[1], raw[2].range[2])
    separator = probe:match("^(%S*)") or ""
  end
  local function strip_separator(s)
    if separator ~= "" and s:sub(1, #separator) == separator then
      return s:sub(#separator + 1)
    end
    return s
  end

  local entries = {}
  for i, e in ipairs(raw) do
    local dr = e.range
    local b = blocks[i]
    local entry = {
      anchor = i,
      movable = true,
      range = { b.start[1], b.start[2], b.finish[1], b.finish[2] },
      lead = get_text(ctx.bufnr, b.start[1], b.start[2], dr[1], dr[2]),
      -- The separator sits between the data and a trailing comment; it is
      -- slot-bound, so strip it from the tail and let render re-emit it.
      tail = strip_separator(get_text(ctx.bufnr, dr[3], dr[4], b.finish[1], b.finish[2])),
    }

    local subject_node = e.node
    if e.entry_kind == "pair" then
      if not e.key_node then
        return nil
      end
      entry.sort_key = ctx.key_normalizer(vim.treesitter.get_node_text(e.key_node, ctx.bufnr))
      subject_node = e.value_node
    else
      entry.sort_key = ctx.key_normalizer(vim.treesitter.get_node_text(e.node, ctx.bufnr))
    end

    local inner = subject_node and ctx.containers_by_id[node_id_key(subject_node)]
    if ctx.deep and inner then
      local child = build_container(inner, ctx)
      if child then
        local vr = { subject_node:range() }
        entry.child = child
        entry.pre = get_text(ctx.bufnr, dr[1], dr[2], vr[1], vr[2])
        entry.post = get_text(ctx.bufnr, vr[3], vr[4], dr[3], dr[4])
      end
    end
    if not entry.child then
      entry.text = get_text(ctx.bufnr, dr[1], dr[2], dr[3], dr[4])
    end

    entries[i] = entry
  end

  local cr = container.range
  local b1, bl = blocks[1], blocks[#blocks]
  local prefix = get_text(ctx.bufnr, cr[1], cr[2], b1.start[1], b1.start[2])

  local joint = " "
  if #raw >= 2 then
    joint = strip_separator(
      get_text(ctx.bufnr, b1.finish[1], b1.finish[2], blocks[2].start[1], blocks[2].start[2])
    )
  end

  -- A trailing separator on the last entry can sit in two places: in the bytes
  -- before the close (no trailing comment), or absorbed before the last entry's
  -- trailing comment (where strip_separator already removed it from the tail).
  -- Either one means render must re-emit a separator after the last entry.
  local after_last = get_text(ctx.bufnr, bl.finish[1], bl.finish[2], cr[3], cr[4])
  local last_dr = raw[#raw].range
  local last_absorbed = get_text(ctx.bufnr, last_dr[3], last_dr[4], bl.finish[1], bl.finish[2])
  local trailing = false
  local suffix = after_last
  if separator ~= "" and last_absorbed:sub(1, #separator) == separator then
    trailing = true
  elseif separator ~= "" and after_last:sub(1, #separator) == separator then
    trailing = true
    suffix = after_last:sub(#separator + 1)
  end

  return {
    kind = container.kind,
    range = cr,
    prefix = prefix,
    suffix = suffix,
    separator = separator,
    joint = joint,
    trailing = trailing,
    entries = entries,
  }
end

-- Visual partial sort: flip top-level entries outside the selection to
-- movable=false so placement keeps them put and only the selected ones move.
local function apply_selection_overlay(outline, selection_range)
  for _, entry in ipairs(outline.entries) do
    if not range_covers_range(selection_range, entry.range) then
      entry.movable = false
    end
  end
end

-- ─── public entry point ─────────────────────────────────────────────────────

---@param bufnr integer
---@param target table  -- { kind="cursor", pos={row,col} } | { kind="selection", range={...} }
---@param pack table    -- { options, query_text, key_normalizer }
---@param deep boolean
---@return table|nil outline
function M.extract(bufnr, target, pack, deep)
  local options = pack.options
  local lang = options.parser_lang or vim.bo[bufnr].filetype

  local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not parser_ok or parser == nil then
    return nil
  end
  local root = parser:parse()[1]:root()
  local query = vim.treesitter.query.parse(lang, pack.query_text)

  local containers, containers_by_id, entries_by_parent, comments_by_parent =
    collect(bufnr, root, query)
  if #containers == 0 then
    return nil
  end

  local chosen = pick_container(containers, target)
  if not chosen then
    return nil
  end

  local outline = build_container(chosen, {
    bufnr = bufnr,
    options = options,
    deep = deep and options.can_deep == true,
    key_normalizer = pack.key_normalizer or function(t)
      return t
    end,
    containers_by_id = containers_by_id,
    entries_by_parent = entries_by_parent,
    comments_by_parent = comments_by_parent,
  })
  if not outline then
    return nil
  end

  if target.kind == "selection" then
    apply_selection_overlay(outline, target.range)
  end

  return outline
end

return M
