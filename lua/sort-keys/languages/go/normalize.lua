-- Go struct-field keys are bare identifiers (pass through); map keys and import
-- paths are interpreted/raw strings, so strip the surrounding quotes.
local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 then
    if text:sub(1, 1) == '"' and text:sub(-1) == '"' then
      return escapes.unescape_json(text:sub(2, -2))
    end
    if text:sub(1, 1) == "`" and text:sub(-1) == "`" then
      return text:sub(2, -2)
    end
  end
  return text
end
