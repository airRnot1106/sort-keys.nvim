-- Turns a raw JS key node's text into the sort key. Keys come as bare
-- identifiers (`a`), quoted string keys (`"a"` / `'a'`), or numbers. Strip the
-- quotes and decode JS escapes (a superset of JSON's) for string keys; bare
-- identifiers and numbers pass through.

local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 then
    local first = text:sub(1, 1)
    if (first == '"' or first == "'") and text:sub(-1) == first then
      return escapes.unescape_js(text:sub(2, -2))
    end
  end
  return text
end
