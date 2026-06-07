-- Normalize a YAML scalar key: plain scalars pass through; a double-quoted key
-- decodes the JSON-shared escapes, a single-quoted key is literal (YAML single
-- quotes only escape '' -> ').
local escapes = require("sort-keys.parse.languages.key_escapes")

---@param text string
---@return string
return function(text)
  if #text >= 2 then
    local q = text:sub(1, 1)
    if q == '"' and text:sub(-1) == '"' then
      return escapes.unescape_json(text:sub(2, -2))
    end
    if q == "'" and text:sub(-1) == "'" then
      return (text:sub(2, -2):gsub("''", "'"))
    end
  end
  return text
end
