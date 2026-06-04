-- Strip the quotes off a Python string key (the common 'x' / "x" forms) and
-- decode the escapes it shares with JSON; non-string keys (numbers, names)
-- pass through. Prefixed/triple-quoted keys are left as their raw text.
local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 then
    local first = text:sub(1, 1)
    if (first == '"' or first == "'") and text:sub(-1) == first then
      return escapes.unescape_json(text:sub(2, -2))
    end
  end
  return text
end
