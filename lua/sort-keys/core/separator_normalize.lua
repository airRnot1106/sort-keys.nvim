local M = {}

-- Treat `separator` as an opaque string. Whitespace-stripping the piece
-- before comparison would defeat languages whose structural separator IS
-- whitespace (e.g., newline-separated formats), so we compare suffixes
-- byte-for-byte instead.

local function piece_tail_is_separator(piece, separator)
  return #piece >= #separator and piece:sub(-#separator) == separator
end

local function gap_contains_separator(gap, separator)
  return gap:find(separator, 1, true) ~= nil
end

local function strip_tail_separator(piece, separator)
  if piece_tail_is_separator(piece, separator) then
    return piece:sub(1, -#separator - 1)
  end
  return piece
end

---Normalize the (pieces, gaps) pair so it can be concatenated as a valid
---sortable body for the host language.
---
---@param pieces string[]
---@param gaps string[]   length must be #pieces - 1
---@param opts { separator: string, trailing_separator_allowed: boolean }
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
  local n = #out_pieces

  for i = 1, n - 1 do
    if
      not (piece_tail_is_separator(out_pieces[i], sep) or gap_contains_separator(out_gaps[i], sep))
    then
      out_gaps[i] = sep .. out_gaps[i]
    end
  end

  if not opts.trailing_separator_allowed and n > 0 then
    out_pieces[n] = strip_tail_separator(out_pieces[n], sep)
  end

  return out_pieces, out_gaps
end

return M
