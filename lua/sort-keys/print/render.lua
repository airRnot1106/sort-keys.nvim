-- The "print" stage: IR -> string, pure. This is the single place separators
-- are emitted, by one language-agnostic rule. Because the framing bytes were
-- observed at extraction, render never needs to know which language it is or
-- which separator family is in play.
--
-- The rule, per container:
--   prefix
--   + for each entry i of n:
--       lead + content(entry)
--       + if i < n : separator + tail + joint        (slot-bound sep, entry-bound tail)
--         else     : (trailing ? separator) + tail
--   + suffix
--
-- `tail` (a same-line trailing comment) travels with its entry; `separator`
-- is slot-bound and therefore drops off whichever entry lands last after a
-- reorder. That split is what keeps `{ "a":1, // c \n "b":2 }` correct when
-- "a" is moved to the end.

local M = {}

---@param entry table
---@return string
local function content_of(entry)
  if entry.child then
    return (entry.pre or "") .. M.render(entry.child) .. (entry.post or "")
  end
  return entry.text
end

---@param container table
---@return string
function M.render(container)
  local out = { container.prefix }
  local n = #container.entries
  for i, entry in ipairs(container.entries) do
    out[#out + 1] = entry.lead or ""
    out[#out + 1] = content_of(entry)
    if i < n then
      out[#out + 1] = container.separator .. (entry.tail or "") .. container.joint
    else
      out[#out + 1] = (container.trailing and container.separator or "") .. (entry.tail or "")
    end
  end
  out[#out + 1] = container.suffix
  return table.concat(out)
end

return M
