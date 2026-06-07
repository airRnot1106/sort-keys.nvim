-- Strip the quotes off a Python string key (triple-quoted """x""" / '''x''' and
-- the common 'x' / "x" forms) and decode the escapes it shares with JSON;
-- non-string keys (numbers, names) pass through. Prefixed strings (r'x', b'x',
-- f'x') and implicit concatenation ('a' 'b') are left as their raw text.
local escapes = require("sort-keys.parse.languages.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 6 then
    local triple = text:sub(1, 3)
    if (triple == '"""' or triple == "'''") and text:sub(-3) == triple then
      return escapes.unescape_json(text:sub(4, -4))
    end
  end
  if #text >= 2 then
    local first = text:sub(1, 1)
    if (first == '"' or first == "'") and text:sub(-1) == first then
      return escapes.unescape_json(text:sub(2, -2))
    end
  end
  return text
end
