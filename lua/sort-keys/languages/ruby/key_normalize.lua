-- Ruby double-quoted strings use a broader escape set than JSON, and an
-- unrecognized escape is a literal `\` + char rather than an error. v1 decodes
-- the simple letter / symbol escapes (including Ruby-only ones like `\s` and
-- `\e`) and leaves the numeric forms (`\xHH`, `\u{...}` brace, octal `\NNN`)
-- as their literal characters — they round-trip stably and decoding them is
-- out of scope. Crucially, an unknown escape must never raise: the sort_key
-- only needs to be stable.
local RUBY_ESCAPES = {
  ["\\"] = "\\",
  ['"'] = '"',
  ["#"] = "#",
  a = "\a",
  b = "\b",
  e = "\27",
  f = "\f",
  n = "\n",
  r = "\r",
  s = " ",
  t = "\t",
  v = "\v",
  ["0"] = "\0",
}

local function unescape_ruby_double(body)
  local out = {}
  local i = 1
  local n = #body
  while i <= n do
    local c = body:sub(i, i)
    if c == "\\" and i + 1 <= n then
      local nxt = body:sub(i + 1, i + 1)
      local simple = RUBY_ESCAPES[nxt]
      if simple then
        out[#out + 1] = simple
      else
        -- Unknown escape (`\x`, `\u`, octal, …): keep the two literal bytes.
        out[#out + 1] = c
        out[#out + 1] = nxt
      end
      i = i + 2
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

-- Ruby hash / keyword keys reach this layer in several surface forms:
--   symbol shorthand  — `name` (a `hash_key_symbol`, already bare)
--   symbol literal     — `:name` / `:"with space"` (a `simple_symbol`)
--   string key         — `"a"` (double, escapes) / `'a'` (single, literal)
--   integer / other    — `2`, returned verbatim
-- A leading `:` is stripped first (symbol), then a quoted remainder is
-- unquoted: double quotes via the Ruby escape decoder, single quotes verbatim
-- (only `\\` / `\'` escape there, left intact in v1).
---@param text string  -- raw node text from a Ruby hash key / keyword label
---@return string
return function(text)
  if text:sub(1, 1) == ":" then
    text = text:sub(2)
  end
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return unescape_ruby_double(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
    return text:sub(2, -2)
  end
  return text
end
