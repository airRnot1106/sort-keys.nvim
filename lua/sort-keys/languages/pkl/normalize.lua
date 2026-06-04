-- Pkl property keys are bare identifiers (pass through); entry keys `["b"]` are
-- string literals, so strip the surrounding quotes and decode the JSON-shared
-- escapes.
local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return escapes.unescape_json(text:sub(2, -2))
  end
  return text
end
