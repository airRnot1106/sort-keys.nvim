-- Pkl keys reach this layer in three surface forms:
--   bare identifier      — `name`, `attendants` (a property's identifier)
--   string-literal key   — `"a"` (the inner expr of a mapping entry `["a"]`)
--   backtick identifier  — `` `default` `` (Pkl escapes keyword identifiers)
-- v1 only strips the delimiters; Pkl's `\n` / `\u{...}` escape decoding is out
-- of scope and round-tripping the literal text keeps the sort_key stable with
-- the source spelling.
---@param text string  -- raw node text from a Pkl property identifier or mapping key
---@return string
return function(text)
  local t = text:match("^%s*(.-)%s*$") or text
  if #t >= 2 and t:sub(1, 1) == '"' and t:sub(-1) == '"' then
    return t:sub(2, -2)
  end
  if #t >= 2 and t:sub(1, 1) == "`" and t:sub(-1) == "`" then
    return t:sub(2, -2)
  end
  return t
end
