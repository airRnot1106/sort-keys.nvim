local M = {}

-- Treat `separator` as an opaque string. Whitespace-stripping the piece
-- before comparison would defeat languages whose structural separator IS
-- whitespace (e.g., newline-separated formats), so we compare suffixes
-- byte-for-byte instead.

local function ends_with(s, sep)
  return #s >= #sep and s:sub(-#sep) == sep
end

local function starts_with(s, sep)
  return #s >= #sep and s:sub(1, #sep) == sep
end

local function gap_contains_separator(gap, separator)
  return gap:find(separator, 1, true) ~= nil
end

---Normalize the (pieces, gaps) pair so it can be concatenated as a valid
---sortable body for the host language.
---
---When `opts.data_lengths` is provided, each piece is treated as
---`data_part .. suffix_part` where `data_part = piece:sub(1, data_lengths[i])`.
---A suffix is what comment_attach absorbed past the entry's original end
---(typically a same-line trailing comment). The policy then splices a
---missing separator BETWEEN data and suffix instead of after the suffix,
---so the separator never ends up buried inside a line-comment.
---
---@param pieces string[]
---@param gaps string[]   length must be #pieces - 1
---@param opts { separator: string, trailing_separator_allowed: boolean, data_lengths: integer[]? }
---@return string[] pieces
---@return string[] gaps
function M.normalize(pieces, gaps, opts)
  local out_pieces = {}
  for i, p in ipairs(pieces) do
    out_pieces[i] = p
  end
  local out_gaps = {}
  for i, g in ipairs(gaps) do
    out_gaps[i] = g
  end

  local sep = opts.separator
  local data_lengths = opts.data_lengths
  local n = #out_pieces

  local function split(i)
    local p = out_pieces[i]
    local dl = data_lengths and data_lengths[i] or #p
    if dl > #p then
      dl = #p
    end
    return p:sub(1, dl), p:sub(dl + 1)
  end

  for i = 1, n - 1 do
    local data_part, suffix_part = split(i)
    if #suffix_part > 0 then
      -- Piece has an absorbed trailing suffix (typically a same-line
      -- comment). The separator must sit BETWEEN data and suffix so it
      -- never lands inside the comment.
      local data_has_sep = ends_with(data_part, sep)
      local suffix_has_sep = starts_with(suffix_part, sep)
      if data_has_sep or suffix_has_sep then
        -- Piece-side already has the separator at the right boundary;
        -- strip a redundant gap-leading separator (carried over from a
        -- different source-position slot) so it does not render after
        -- the comment and look like a duplicate.
        if starts_with(out_gaps[i], sep) then
          out_gaps[i] = out_gaps[i]:sub(#sep + 1)
        end
      elseif starts_with(out_gaps[i], sep) then
        -- Gap leading carries the slot's separator; relocate it into
        -- the piece's data/suffix boundary so it lands before the
        -- comment, not after it.
        out_pieces[i] = data_part .. sep .. suffix_part
        out_gaps[i] = out_gaps[i]:sub(#sep + 1)
      elseif not gap_contains_separator(out_gaps[i], sep) then
        -- No separator anywhere in the slot; splice into the piece.
        out_pieces[i] = data_part .. sep .. suffix_part
      end
    else
      -- No suffix to step over — historical "has sep anywhere in the
      -- slot" check + gap-prepend keeps the separator at the same
      -- visual position as before.
      local has_sep = ends_with(data_part, sep) or gap_contains_separator(out_gaps[i], sep)
      if not has_sep then
        out_gaps[i] = sep .. out_gaps[i]
      end
    end
  end

  if n > 0 then
    local data_part, suffix_part = split(n)
    if not opts.trailing_separator_allowed then
      if starts_with(suffix_part, sep) then
        out_pieces[n] = data_part .. suffix_part:sub(#sep + 1)
      elseif ends_with(data_part, sep) then
        out_pieces[n] = data_part:sub(1, -#sep - 1) .. suffix_part
      end
    elseif opts.source_last_had_trailing_sep then
      -- The applier observed that the source's last entry carried a
      -- trailing separator (e.g. JSONC's pervasive trailing-comma
      -- style). Reordering can move the new-last entry out of that
      -- slot, so add one back to keep the style consistent.
      local has_trailing = starts_with(suffix_part, sep) or ends_with(data_part, sep)
      if not has_trailing then
        out_pieces[n] = data_part .. sep .. suffix_part
      end
    end
  end

  return out_pieces, out_gaps
end

return M
