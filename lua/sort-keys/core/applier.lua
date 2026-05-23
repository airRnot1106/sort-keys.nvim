local separator_normalize = require("sort-keys.core.separator_normalize")

local M = {}

---@param bufnr integer
---@param range table 4-tuple {srow, scol, erow, ecol}
---@return string
local function read_text(bufnr, range)
  local lines = vim.api.nvim_buf_get_text(bufnr, range[1], range[2], range[3], range[4], {})
  return table.concat(lines, "\n")
end

local function render_entry(bufnr, entry, render_outline)
  if entry.child then
    local er = entry.range
    local cr = entry.child.range
    local prefix = read_text(bufnr, { er[1], er[2], cr[1], cr[2] })
    local middle = render_outline(bufnr, entry.child)
    local suffix = read_text(bufnr, { cr[3], cr[4], er[3], er[4] })
    return prefix .. middle .. suffix
  end
  return read_text(bufnr, entry.range)
end

local function render_outline(bufnr, outline)
  local r = outline.range
  if #outline.entries == 0 then
    return read_text(bufnr, r)
  end

  local by_position = {}
  for _, e in ipairs(outline.entries) do
    by_position[#by_position + 1] = e
  end
  table.sort(by_position, function(a, b)
    if a.range[1] ~= b.range[1] then
      return a.range[1] < b.range[1]
    end
    return a.range[2] < b.range[2]
  end)

  local first = by_position[1]
  local last = by_position[#by_position]
  local prefix = read_text(bufnr, { r[1], r[2], first.range[1], first.range[2] })
  local suffix = read_text(bufnr, { last.range[3], last.range[4], r[3], r[4] })

  local gaps = {}
  for i = 1, #by_position - 1 do
    local cur = by_position[i]
    local nxt = by_position[i + 1]
    gaps[i] = read_text(bufnr, { cur.range[3], cur.range[4], nxt.range[1], nxt.range[2] })
  end

  local pieces = {}
  for _, e in ipairs(outline.entries) do
    pieces[#pieces + 1] = render_entry(bufnr, e, render_outline)
  end

  -- `structural_separator` is declared verbatim by each language's .toml so
  -- the applier never has to know which character a language uses. If the
  -- field is absent or empty the language has no inter-entry separator
  -- (e.g., newline-based formats) and normalization is skipped.
  if outline.structural_separator and #outline.structural_separator > 0 then
    pieces, gaps = separator_normalize.normalize(pieces, gaps, {
      separator = outline.structural_separator,
      trailing_separator_allowed = outline.trailing_separator_allowed == true,
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
