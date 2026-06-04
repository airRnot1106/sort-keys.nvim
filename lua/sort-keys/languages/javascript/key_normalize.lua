local escapes = require("sort-keys.core.key_escapes")

-- JS single-quoted strings use the backslash escape set: `\'`, `\\`, `\n`,
-- etc. — same shape as double-quoted, just with `'` as the quote-escape
-- target. The JSON escape decoder handles every other case identically.
local SINGLE_QUOTE_ESCAPES = {
  ["'"] = "'",
  ["\\"] = "\\",
  ["/"] = "/",
  b = "\b",
  f = "\f",
  n = "\n",
  r = "\r",
  t = "\t",
}

local function unescape_js_single_quoted(body)
  local out = {}
  local i = 1
  local n = #body
  while i <= n do
    local c = body:sub(i, i)
    if c == "\\" and i + 1 <= n then
      local nxt = body:sub(i + 1, i + 1)
      local simple = SINGLE_QUOTE_ESCAPES[nxt]
      if simple then
        out[#out + 1] = simple
        i = i + 2
      else
        out[#out + 1] = nxt
        i = i + 2
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

---@param text string  -- raw node text from a JS object key node
---@return string
return function(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return escapes.unescape_json(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
    return unescape_js_single_quoted(text:sub(2, -2))
  end
  return text
end
