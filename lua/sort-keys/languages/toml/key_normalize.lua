local escapes = require("sort-keys.core.key_escapes")

-- TOML keys have three surface forms (TOML 1.0):
--   bare_key       — `foo`, `bar-1`, `_baz`
--   basic string   — `"foo"`, with JSON-style escapes (`\n`, `\"`, `\uXXXX`)
--   literal string — `'foo'`, no escape processing at all
-- Dotted keys (`a.b.c`) appear as one `dotted_key` node whose text contains
-- the dots and any quoted segments; v1 returns that text verbatim so the
-- whole dotted path becomes a single flat sort_key (per-segment normalization
-- + nested-table expansion is out of scope for v1).
---@param text string  -- raw node text from a TOML key node
---@return string
return function(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return escapes.unescape_json(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
    return text:sub(2, -2)
  end
  return text
end
