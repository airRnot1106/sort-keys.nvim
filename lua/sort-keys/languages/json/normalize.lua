-- Turns a raw JSON key node's text into the canonical sort_key: strip the
-- surrounding double quotes, then decode JSON escapes so `é` and the
-- literal "é" collate identically. Pure (depends only on core.key_escapes),
-- so it is tested without nvim.

local escapes = require("sort-keys.core.key_escapes")

---@param text string
---@return string
return function(text)
  return escapes.unescape_json(escapes.strip_double_quotes(text))
end
