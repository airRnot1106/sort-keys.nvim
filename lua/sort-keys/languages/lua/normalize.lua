-- Turns a raw Lua key node's text into the sort key. Keys come as bare
-- identifiers (`a`), or as bracketed string keys (`["a"]` / `['a']`) whose name
-- node is the string literal. Quote the string forms away and decode their
-- escapes; bare identifiers pass through.

local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 then
    local first = text:sub(1, 1)
    if first == '"' and text:sub(-1) == '"' then
      return escapes.unescape_json(text:sub(2, -2))
    end
    if first == "'" and text:sub(-1) == "'" then
      return escapes.unescape_json(text:sub(2, -2))
    end
  end
  return text
end
