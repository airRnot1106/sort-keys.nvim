-- Normalize an Elixir map key so the keyword form `b:`, the atom `:b`, and the
-- string `"b"` collate as `b`. A keyword key node's text is like `b: `, so take
-- the name before the colon; otherwise strip an atom colon or string quotes.
local escapes = require("sort-keys.parse.languages.key_escapes")

---@param text string
---@return string
return function(text)
  local kw = text:match("^%s*([%w_]+[?!]?)%s*:%s*$")
  if kw then
    return kw
  end
  -- A quoted keyword key node's text is like `"weird key": `.
  local quoted_kw = text:match('^%s*"(.*)"%s*:%s*$')
  if quoted_kw then
    return escapes.unescape_json(quoted_kw)
  end
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return escapes.unescape_json(text:sub(2, -2))
  end
  if text:sub(1, 1) == ":" then
    return text:sub(2)
  end
  return text
end
