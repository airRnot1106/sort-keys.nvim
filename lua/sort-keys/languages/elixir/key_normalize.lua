local escapes = require("sort-keys.core.key_escapes")

-- Elixir keys arrive in three surface forms, each carrying syntax the logical
-- key must shed:
--   keyword shorthand — `name: ` / `"foo bar": ` (trailing `:` and space)
--   atom (arrow keys) — `:foo` / `:"foo bar"` (leading `:`)
--   string (arrow keys) — `"a"`
-- After dropping the colon, a quoted remainder is unquoted with the JSON
-- escape decoder (Elixir's `\n` / `\"` / `\\` / `\uXXXX` set overlaps it).
---@param text string  -- raw node text from an Elixir keyword / atom / string key
---@return string
return function(text)
  text = text:gsub("%s+$", "")
  local keyword = text:match("^(.*):$")
  if keyword then
    text = keyword
  else
    local atom = text:match("^:(.*)$")
    if atom then
      text = atom
    end
  end
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return escapes.unescape_json(text:sub(2, -2))
  end
  return text
end
