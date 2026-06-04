-- Shared between JSON and JSONC handlers so that both produce identical
-- sort_key bytes for the same logical key.

local escapes = require("sort-keys.core.key_escapes")

---@param text string  -- raw node text; may be quoted or an already-stripped string_content
---@return string
return function(text)
  return escapes.unescape_json(escapes.strip_double_quotes(text))
end
