-- TOML keys are bare (`a`), dotted (`a.b.c`), or quoted (`"a"` / `'a'`). Bare
-- and dotted pass through; quoted keys are stripped (double quotes decode the
-- JSON-shared escapes, single quotes are literal).
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
      return text:sub(2, -2)
    end
  end
  return text
end
