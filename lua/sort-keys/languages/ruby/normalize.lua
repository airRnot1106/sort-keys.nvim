-- Normalize a Ruby hash key so the symbol form `b:`, the symbol literal `:b`,
-- and the string form `"b"` all collate as `b`. hash_key_symbol nodes are
-- already the bare name; strip a leading `:` (simple_symbol) or surrounding
-- quotes (string), decoding the escapes a quoted key shares with JSON.
local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 then
    local first = text:sub(1, 1)
    if (first == '"' or first == "'") and text:sub(-1) == first then
      return escapes.unescape_json(text:sub(2, -2))
    end
    if first == ":" then
      return text:sub(2)
    end
  end
  return text
end
