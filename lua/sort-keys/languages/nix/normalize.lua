-- Nix attrpaths are bare (possibly dotted `a.b.c`) and pass through; a quoted
-- attr `"a"` is stripped and JSON-escape-decoded.
local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return escapes.unescape_json(text:sub(2, -2))
  end
  return text
end
