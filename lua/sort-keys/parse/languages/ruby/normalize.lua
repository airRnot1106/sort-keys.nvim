-- Normalize a Ruby hash key so the symbol form `b:`, the symbol literal `:b`,
-- the quoted symbol `:"b"`, and the string form `"b"` all collate as `b`.
local escapes = require("sort-keys.parse.languages.key_escapes")

-- Strip surrounding quotes. Double quotes decode the JSON-shared escape set;
-- Ruby single quotes are literal (only \\ and \' are escapes).
local function strip_quotes(s)
  if #s < 2 then
    return s
  end
  local q = s:sub(1, 1)
  if q == '"' and s:sub(-1) == '"' then
    return escapes.unescape_json(s:sub(2, -2))
  end
  if q == "'" and s:sub(-1) == "'" then
    return (s:sub(2, -2):gsub("\\([\\'])", "%1"))
  end
  return s
end

---@param text string
---@return string
return function(text)
  -- A symbol literal (:b, :"a b", :'a') keeps its name after the colon; the
  -- same quote-stripping then applies so :"abc" collates with abc:.
  if text:sub(1, 1) == ":" then
    text = text:sub(2)
  end
  return strip_quotes(text)
end
