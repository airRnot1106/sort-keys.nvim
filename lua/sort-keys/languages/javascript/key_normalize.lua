local escapes = require("sort-keys.core.key_escapes")

-- JS object keys come quoted ("..." / '...') or bare. Both quote styles share
-- the same backslash escape set, which is a superset of JSON's — an unknown
-- escape like `\s` is legal and means the bare character, and `\xNN` / `\u{...}`
-- are JS-only forms. `escapes.unescape_js` decodes all of them leniently (it
-- never raises), so a valid-but-non-JSON key can't crash sorting.
---@param text string  -- raw node text from a JS object key node
---@return string
return function(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return escapes.unescape_js(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
    return escapes.unescape_js(text:sub(2, -2))
  end
  return text
end
