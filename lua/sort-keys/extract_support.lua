-- Shared treesitter/buffer-aware scaffolding for the parse stage. Every
-- extractor — the generic one and any per-language custom extractor for an
-- irregular AST — composes these: the IR builder (frame observation, comment
-- folding, separator peeling, deep recursion), target-container picking, the
-- Visual overlay, and an orchestrator that wires parser → collect → build.
--
-- An extractor only supplies its own `collect`: how to turn a parse tree into
-- containers (+ their kind), entries grouped by parent, and comments. Everything
-- downstream of that is identical regardless of language, which is what keeps a
-- custom extractor thin.

local comment_fold = require("sort-keys.core.comment_fold")
local pos = require("sort-keys.core.pos")

local M = {}

---@param bufnr integer
function M.get_text(bufnr, sr, sc, er, ec)
  return table.concat(vim.api.nvim_buf_get_text(bufnr, sr, sc, er, ec, {}), "\n")
end

---String identity for a node, stable across iter_matches calls.
function M.node_id_key(node)
  local sr, sc, er, ec = node:range()
  return string.format("%s:%d:%d:%d:%d", node:type(), sr, sc, er, ec)
end

-- Pull a range back inside the buffer. Some grammars (YAML block nodes) give a
-- node a range that ends at the start of the line *after* its content, i.e.
-- past the last buffer line, which would make nvim_buf_get_text error.
function M.clamp_range(bufnr, r)
  local last = vim.api.nvim_buf_line_count(bufnr) - 1
  local function len(row)
    return #(vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or "")
  end
  local sr, sc, er, ec
  if r[1] > last then
    sr, sc = last, len(last)
  else
    sr, sc = r[1], math.min(r[2], len(r[1]))
  end
  if r[3] > last then
    er, ec = last, len(last)
  else
    er, ec = r[3], math.min(r[4], len(r[3]))
  end
  return { sr, sc, er, ec }
end

local function range_area(r)
  return (r[3] - r[1]) * 1000000 + (r[4] - r[2])
end

-- Innermost container for the target. Cursor: smallest container containing the
-- position. Selection (line-wise): smallest container whose rows cover the
-- whole selection; if none (e.g. the selection runs past the closing bracket),
-- fall back to the smallest container whose rows contain the selection's first
-- line. This keeps :'<,'>SortKeys working even when the selected lines don't
-- align with the container's exact start/end columns.
function M.pick_container(containers, target)
  local best, best_area
  local function consider(c)
    local area = range_area(c.range)
    if best_area == nil or area < best_area then
      best, best_area = c, area
    end
  end

  if target.kind == "cursor" then
    for _, c in ipairs(containers) do
      if pos.contains(c.range, target.pos[1], target.pos[2]) then
        consider(c)
      end
    end
    return best
  end

  for _, c in ipairs(containers) do
    if pos.rows_cover(c.range, target.srow, target.erow) then
      consider(c)
    end
  end
  if best then
    return best
  end
  for _, c in ipairs(containers) do
    if pos.row_in_span(c.range, target.srow) then
      consider(c)
    end
  end
  return best
end

-- The container nested under an entry's subject, for deep recursion: the
-- subject node itself when it IS a captured container (JSON pairs, Lua fields),
-- else one level down when the value wraps it (a YAML block_node around a
-- block_mapping, a Rust struct_expression around a field_initializer_list).
local function find_inner_container(node, containers_by_id)
  local direct = containers_by_id[M.node_id_key(node)]
  if direct then
    return direct
  end
  for child in node:iter_children() do
    if child:named() then
      local c = containers_by_id[M.node_id_key(child)]
      if c then
        return c
      end
    end
  end
  return nil
end

local function capability_allows(kind, options)
  if kind == "object" then
    return options.can_sort_object == true
  end
  if kind == "array" then
    return options.can_sort_array == true
  end
  return false
end

-- Build the IR for one container. `ctx` carries bufnr, options, deep,
-- key_normalizer, and the collect output (containers_by_id, entries_by_parent,
-- comments_by_parent). Recurses through containers_by_id for deep sort.
function M.build_container(container, ctx)
  if not capability_allows(container.kind, ctx.options) then
    return nil
  end

  local node_id_key = M.node_id_key
  local get_text = M.get_text

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
  -- Pull entry ranges inside the buffer before any text slicing (a YAML pair's
  -- range can end past the last line).
  for _, e in ipairs(raw) do
    e.range = M.clamp_range(ctx.bufnr, e.range)
  end

  local container_comments = {}
  if ctx.options.comment_aware then
    container_comments = ctx.comments_by_parent[node_id_key(container.node)] or {}
  end
  local blocks = comment_fold.fold(raw, container_comments)

  -- Separator: the first non-whitespace run after the first entry's DATA. The
  -- leading-whitespace skip means a delimiter that is not byte-adjacent (e.g. a
  -- comma at the start of the next line) is still observed; probing from the
  -- data end means a trailing comment after the data does not hide it.
  -- The delimiter is a single punctuation character in every supported
  -- language (","  ";"  or none); match exactly one non-whitespace char so a
  -- malformed gap with two (a JS array elision `,,`) doesn't get swallowed
  -- whole into the separator and re-emitted between every entry.
  -- A pack may pin the separator (options.separator) when the gap can't be
  -- probed reliably — e.g. KDL is space-separated but a `\` line continuation
  -- in the gap would otherwise be misread as a delimiter. Otherwise observe it.
  local separator = ctx.options.separator
  if separator == nil and #raw >= 2 then
    separator = ""
    -- Stop the probe at any comment sitting in the gap: a comment's "#"/"//" is
    -- not a delimiter, so for a whitespace-separated language (block YAML) the
    -- probe must see only the whitespace before it, not the comment.
    local pe_row, pe_col = raw[2].range[1], raw[2].range[2]
    for _, c in ipairs(container_comments) do
      local cr0 = c.range
      if
        pos.lt(raw[1].range[3], raw[1].range[4], cr0[1], cr0[2])
        and pos.lt(cr0[1], cr0[2], pe_row, pe_col)
      then
        pe_row, pe_col = cr0[1], cr0[2]
      end
    end
    local probe = get_text(ctx.bufnr, raw[1].range[3], raw[1].range[4], pe_row, pe_col)
    separator = probe:match("^%s*(%S)") or ""
  end
  separator = separator or ""
  -- Peel one separator off s -> (rest, had_separator). The separator is
  -- slot-bound, so it is stripped from tails / inter-block gaps here and
  -- re-emitted by render. Peels only a LEADING separator (the usual
  -- trailing-delimiter style "a": 1,\n). Used for tails, trailing detection,
  -- and the inter-block gap. It must NOT strip a trailing byte that merely
  -- equals the separator — a comment ending in "," is content, not a delimiter.
  local function peel_separator(s)
    if separator ~= "" and s:sub(1, #separator) == separator then
      return s:sub(#separator + 1), true
    end
    return s, false
  end

  -- The inter-entry gap (joint) may instead carry the delimiter at its BACK in
  -- a leading-delimiter layout (\n  ,"b"); strip whichever end has it so the
  -- joint is pure whitespace and render normalizes to the trailing style.
  local function peel_joint(s)
    local rest, had = peel_separator(s)
    if had then
      return rest
    end
    if separator ~= "" and #s >= #separator and s:sub(-#separator) == separator then
      return s:sub(1, -#separator - 1)
    end
    return s
  end

  local entries = {}
  for i, e in ipairs(raw) do
    local dr = e.range
    local b = blocks[i]
    local entry = {
      anchor = i,
      movable = e.movable ~= false,
      fence = e.fence,
      range = { b.start[1], b.start[2], b.finish[1], b.finish[2] },
      lead = get_text(ctx.bufnr, b.start[1], b.start[2], dr[1], dr[2]),
      tail = (peel_separator(get_text(ctx.bufnr, dr[3], dr[4], b.finish[1], b.finish[2]))),
    }

    if e.entry_kind == "pair" then
      -- A pair with no key node is a null-key pair (valid YAML `: value`); it
      -- still must be captured as an entry so its framing/comment round-trip,
      -- and it sorts as the empty key.
      entry.sort_key = e.key_node
          and ctx.key_normalizer(vim.treesitter.get_node_text(e.key_node, ctx.bufnr))
        or ""
    else
      entry.sort_key = ctx.key_normalizer(vim.treesitter.get_node_text(e.node, ctx.bufnr))
      -- An array element sorts by its own content, so when deep sort reorders
      -- that content the ordering key must be re-derived from the sorted child
      -- (see core/traverse). Mark it so traverse knows not to treat sort_key as
      -- a stable, separate key the way it does for a pair.
      entry.value_keyed = true
    end

    -- The node carrying a nested container for deep recursion: the value node
    -- when the entry has one (JSON pairs, Lua fields), else the entry node
    -- itself (JSON array elements, which ARE the value).
    local subject_node = e.value_node or e.node

    local inner = subject_node and find_inner_container(subject_node, ctx.containers_by_id)
    if ctx.deep and inner then
      local child = M.build_container(inner, ctx)
      if child then
        -- Slice pre/post around the INNER container's range, not the subject
        -- node's: when the value wraps the container (find_inner_container went
        -- one level down), the wrapper's leading text (a Pkl key, a YAML
        -- block_node indent) must be preserved as `pre`.
        local vr = child.range
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

  local cr = M.clamp_range(ctx.bufnr, container.range)
  local b1, bl = blocks[1], blocks[#blocks]
  local prefix = get_text(ctx.bufnr, cr[1], cr[2], b1.start[1], b1.start[2])

  local joint = " "
  if #raw >= 2 then
    joint = peel_joint(
      get_text(ctx.bufnr, b1.finish[1], b1.finish[2], blocks[2].start[1], blocks[2].start[2])
    )
    -- A joint that still carries the delimiter means the inter-entry gap held an
    -- extra one with no node behind it (a JS array elision `[a,,b]`). Re-emitting
    -- the observed joint would duplicate it, so leave the container untouched
    -- rather than corrupt it.
    if separator ~= "" and joint:find(separator, 1, true) then
      return nil
    end
  end

  -- A trailing separator on the last entry can sit in two places: in the bytes
  -- before the close (no trailing comment), or absorbed before the last entry's
  -- trailing comment (already peeled out of its tail). Either means render must
  -- re-emit a separator after the last entry.
  local after_last = get_text(ctx.bufnr, bl.finish[1], bl.finish[2], cr[3], cr[4])
  local last_dr = raw[#raw].range
  local _, absorbed_separator =
    peel_separator(get_text(ctx.bufnr, last_dr[3], last_dr[4], bl.finish[1], bl.finish[2]))
  local trailing = false
  local suffix = after_last
  if absorbed_separator then
    trailing = true
  else
    local rest, had = peel_separator(after_last)
    if had then
      trailing = true
      suffix = rest
    end
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

-- Visual partial sort: pin entries whose lines fall outside the selection so
-- placement keeps them put and only the selected ones reorder.
local function apply_selection_overlay(outline, target)
  for _, entry in ipairs(outline.entries) do
    if not pos.rows_overlap(entry.range, target.srow, target.erow) then
      entry.movable = false
    end
  end
end

-- Orchestrate one extraction. `collect(bufnr, root, query)` is the only
-- per-extractor piece; it returns containers, containers_by_id,
-- entries_by_parent, comments_by_parent.
---@param bufnr integer
---@param target table
---@param pack table
---@param deep boolean
---@param collect fun(bufnr: integer, root: TSNode, query: table): table[], table, table, table
---@return table|nil outline
function M.run(bufnr, target, pack, deep, collect)
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

  local chosen = M.pick_container(containers, target)
  if not chosen then
    return nil
  end

  local outline = M.build_container(chosen, {
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
    apply_selection_overlay(outline, target)
  end

  return outline
end

return M
