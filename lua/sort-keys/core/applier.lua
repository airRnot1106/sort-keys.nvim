local separator_normalize = require("sort-keys.core.separator_normalize")

local M = {}

---@param bufnr integer
---@param range table 4-tuple {srow, scol, erow, ecol}
---@return string
local function read_text(bufnr, range)
  local lines = vim.api.nvim_buf_get_text(bufnr, range[1], range[2], range[3], range[4], {})
  return table.concat(lines, "\n")
end

-- Returns (piece_text, data_length). `data_length` is the byte offset in
-- piece_text where the entry's data ends and an absorbed trailing comment
-- begins; it is `#piece_text` when nothing was absorbed past the data.
-- separator_normalize uses it to splice a missing inter-entry separator
-- BETWEEN data and suffix so the separator never lands inside a line-
-- comment that comment_attach merged into the piece.
local function render_entry(bufnr, entry, render_outline)
  if entry.child then
    local er = entry.range
    local cr = entry.child.range
    local prefix = read_text(bufnr, { er[1], er[2], cr[1], cr[2] })
    local middle = render_outline(bufnr, entry.child)
    local suffix = read_text(bufnr, { cr[3], cr[4], er[3], er[4] })
    return prefix .. middle .. suffix, #prefix + #middle
  end
  local piece = read_text(bufnr, entry.range)
  if
    entry.data_range
    and (entry.data_range[3] ~= entry.range[3] or entry.data_range[4] ~= entry.range[4])
  then
    -- Trailing absorbed comment: data ends at data_range[3,4].
    local data_text = read_text(bufnr, {
      entry.range[1],
      entry.range[2],
      entry.data_range[3],
      entry.data_range[4],
    })
    return piece, #data_text
  end
  return piece, #piece
end

local function render_outline(bufnr, outline)
  local r = outline.range
  if #outline.entries == 0 then
    return read_text(bufnr, r)
  end

  local function by_source_position(list)
    local out = {}
    for _, e in ipairs(list) do
      out[#out + 1] = e
    end
    table.sort(out, function(a, b)
      if a.range[1] ~= b.range[1] then
        return a.range[1] < b.range[1]
      end
      return a.range[2] < b.range[2]
    end)
    return out
  end

  -- Full source partition = survivors + entries the `u` flag dropped. The
  -- container's prefix / inter-entry gaps / suffix are recovered from this
  -- complete partition so dropped spans never leak back into the output; the
  -- dropped entries themselves are never emitted as pieces.
  local combined = {}
  for _, e in ipairs(outline.entries) do
    combined[#combined + 1] = e
  end
  for _, e in ipairs(outline.dropped or {}) do
    combined[#combined + 1] = e
  end
  local all = by_source_position(combined)

  local first = all[1]
  local last_all = all[#all]
  local prefix = read_text(bufnr, { r[1], r[2], first.range[1], first.range[2] })
  local suffix = read_text(bufnr, { last_all.range[3], last_all.range[4], r[3], r[4] })

  local all_gaps = {}
  for i = 1, #all - 1 do
    local cur = all[i]
    local nxt = all[i + 1]
    all_gaps[i] = read_text(bufnr, { cur.range[3], cur.range[4], nxt.range[1], nxt.range[2] })
  end

  -- Trailing-separator style is judged by the source-position-last SURVIVOR
  -- (a dropped entry must not stand in for it).
  local survivors_by_position = by_source_position(outline.entries)
  local last_survivor = survivors_by_position[#survivors_by_position]

  local pieces = {}
  local data_lengths = {}
  local source_last_idx
  for i, e in ipairs(outline.entries) do
    local p, dl = render_entry(bufnr, e, render_outline)
    pieces[#pieces + 1] = p
    data_lengths[#data_lengths + 1] = dl
    if e == last_survivor then
      source_last_idx = i
    end
  end

  -- Only #pieces-1 gaps separate the surviving pieces; borrow the first
  -- ones from the full partition so their whitespace/indentation style is
  -- preserved (gaps are uniform in practice). Identical to the old behavior
  -- when nothing was dropped (#pieces == #all).
  local gaps = {}
  for i = 1, #pieces - 1 do
    gaps[i] = all_gaps[i] or ""
  end

  -- `structural_separator` is declared verbatim by each language's .toml so
  -- the applier never has to know which character a language uses. If the
  -- field is absent or empty the language has no inter-entry separator
  -- (e.g., newline-based formats) and normalization is skipped.
  if outline.structural_separator and #outline.structural_separator > 0 then
    local sep = outline.structural_separator
    local source_last_had_trailing_sep = false
    if source_last_idx then
      local p = pieces[source_last_idx]
      local dl = data_lengths[source_last_idx]
      local data_part = p:sub(1, dl)
      local suffix_part = p:sub(dl + 1)
      -- The source's last entry signals trailing-separator style iff its
      -- piece carries the sep at the data/suffix boundary (either at
      -- data's tail or at the absorbed suffix's leading position). The
      -- check is on the SOURCE-position last entry, not the sorted-last,
      -- so reordering can preserve that style on the new last piece.
      source_last_had_trailing_sep = (#suffix_part >= #sep and suffix_part:sub(1, #sep) == sep)
        or (#data_part >= #sep and data_part:sub(-#sep) == sep)
    end
    pieces, gaps = separator_normalize.normalize(pieces, gaps, {
      separator = sep,
      trailing_separator_allowed = outline.trailing_separator_allowed == true,
      data_lengths = data_lengths,
      source_last_had_trailing_sep = source_last_had_trailing_sep,
    })
  end

  local result = prefix .. pieces[1]
  for i = 1, #gaps do
    result = result .. gaps[i] .. pieces[i + 1]
  end
  return result .. suffix
end

---@param bufnr integer
---@param outline table
function M.apply(bufnr, outline)
  local new_text = render_outline(bufnr, outline)
  local r = outline.range
  local replacement = vim.split(new_text, "\n", { plain = true })
  vim.api.nvim_buf_set_text(bufnr, r[1], r[2], r[3], r[4], replacement)
end

return M
