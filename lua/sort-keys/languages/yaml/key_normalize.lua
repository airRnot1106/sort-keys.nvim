local escapes = require("sort-keys.core.key_escapes")

local function unescape_single_quoted(body)
  -- The only escape inside YAML single-quoted scalars is `''` for a literal
  -- `'`. Everything else is taken verbatim, so a simple gsub suffices.
  return (body:gsub("''", "'"))
end

---@param text string  -- raw node text; bare, single-quoted, or double-quoted YAML scalar
---@return string
return function(text)
  local trimmed = text:match("^%s*(.-)%s*$") or text
  if #trimmed >= 2 and trimmed:sub(1, 1) == '"' and trimmed:sub(-1) == '"' then
    return escapes.unescape_json(trimmed:sub(2, -2))
  end
  if #trimmed >= 2 and trimmed:sub(1, 1) == "'" and trimmed:sub(-1) == "'" then
    return unescape_single_quoted(trimmed:sub(2, -2))
  end
  return trimmed
end
