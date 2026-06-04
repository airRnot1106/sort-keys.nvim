-- The intermediate representation shared by the whole pipeline:
--   parse (extract) -> transform (sort) -> print (render).
--
-- A Container is self-renderable: it carries the *observed* framing bytes so
-- that the separator concern collapses to "extract observes / render applies
-- one rule". No part of the transform layer (order/placement/traverse) ever
-- reads these framing fields — they only permute `entries`.
--
--   Container = {
--     kind      = "object" | "array",
--     range     = { srow, scol, erow, ecol }, -- 0-indexed, end-exclusive; the
--                                              --   span apply.lua overwrites.
--     prefix    = "{\n  ",   -- observed: container open up to the first entry
--     suffix    = "\n}",     -- observed: after the last entry's data to close
--     separator = ",",       -- observed: inter-entry delimiter ("" if whitespace-gapped)
--     joint     = "\n  ",    -- observed: whitespace between separator and next entry
--     trailing  = false,     -- observed: did the source put a separator after the last entry?
--     entries   = Entry[],
--   }
--
--   Entry = {
--     sort_key = "...",       -- logical key after normalization (drives ordering)
--     text     = "\"a\": 1",  -- raw source span; rendered verbatim when child == nil
--     lead     = "",          -- own-line leading trivia that travels with this entry
--     tail     = "",          -- same-line trailing trivia that travels with this entry
--     movable  = true,        -- false = pinned at its source slot
--     anchor   = 1,           -- 1-based source-order index
--     fence    = nil,         -- true (with movable=false) = movables can't cross it
--     child    = nil | Container, -- nested container for deep sort
--     pre      = "\"a\": ",   -- text before child (used only when child ~= nil)
--     post     = "",          -- text after child  (used only when child ~= nil)
--   }
--
-- The copy helpers forward every field via `pairs`, so adding a new IR field
-- never silently drops it at a rebuild site (placement overlay, deep recursion).

local M = {}

---@param entry table
---@param overrides table?
---@return table
function M.copy_entry(entry, overrides)
  local out = {}
  for k, v in pairs(entry) do
    out[k] = v
  end
  if overrides then
    for k, v in pairs(overrides) do
      out[k] = v
    end
  end
  return out
end

---@param container table
---@param overrides table?
---@return table
function M.copy_container(container, overrides)
  local out = {}
  for k, v in pairs(container) do
    out[k] = v
  end
  if overrides then
    for k, v in pairs(overrides) do
      out[k] = v
    end
  end
  return out
end

return M
