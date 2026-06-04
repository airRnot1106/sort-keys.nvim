-- Pkl property keys are bare identifiers (pass through); entry keys `["b"]` are
-- string literals, so strip the surrounding quotes and decode the JSON-shared
-- escapes.
local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 then
    if text:sub(1, 1) == '"' and text:sub(-1) == '"' then
      return escapes.unescape_json(text:sub(2, -2))
    end
    -- A backtick-quoted identifier `weird key` is literal; just unwrap it.
    if text:sub(1, 1) == "`" and text:sub(-1) == "`" then
      return text:sub(2, -2)
    end
  end
  return text
end
