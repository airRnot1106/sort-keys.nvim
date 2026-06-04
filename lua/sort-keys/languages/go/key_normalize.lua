local escapes = require("sort-keys.core.key_escapes")

-- Go keys reach this layer in three surface forms:
--   bare identifier         — struct field names (`Foo`, `bar_baz`); returned verbatim
--   interpreted_string_literal — `"foo\nbar"` map keys; same backslash set as JSON
--   raw_string_literal      — `` `foo\nbar` `` map keys; escapes are NOT processed
-- The interpreted form shares the JSON escape decoder for the simple escapes
-- and `\uXXXX` (Go's `\xNN` / `\u{...}` astral escapes are rare in map keys
-- and round-trip stably as verbatim text; v1 leaves them to the decoder's
-- fallback path which keeps the sort_key faithful to the source).
---@param text string  -- raw node text from a Go field / map-key node
---@return string
return function(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return escapes.unescape_json(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "`" and text:sub(-1) == "`" then
    return text:sub(2, -2)
  end
  return text
end
