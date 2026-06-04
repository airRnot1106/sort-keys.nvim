-- Lua's escape set adds `\a` / `\v` (forbidden in JSON) and accepts `\'` in
-- double-quoted strings as well. `\xNN` / `\ddd` / `\u{...}` / `\z` are valid
-- Lua escapes but rare in keys; v1 leaves them as-is and they round-trip
-- through the sort_key intact, which is enough for ordering.

local LUA_ESCAPES = {
  ["\\"] = "\\",
  ['"'] = '"',
  ["'"] = "'",
  a = "\a",
  b = "\b",
  f = "\f",
  n = "\n",
  r = "\r",
  t = "\t",
  v = "\v",
}

local function unescape_lua_quoted(body)
  local out = {}
  local i = 1
  local n = #body
  while i <= n do
    local c = body:sub(i, i)
    if c == "\\" and i + 1 <= n then
      local nxt = body:sub(i + 1, i + 1)
      local simple = LUA_ESCAPES[nxt]
      if simple then
        out[#out + 1] = simple
        i = i + 2
      else
        out[#out + 1] = c
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

local function strip_long_bracket(text)
  -- Match `[` + N `=` + `[` ... `]` + N `=` + `]` for any N >= 0.
  local open_eq, body = text:match("^%[(=*)%[(.-)%]" .. "%1" .. "%]$")
  if open_eq and body then
    return body
  end
  return nil
end

---@param text string  -- raw node text from a Lua table-field key node
---@return string
return function(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return unescape_lua_quoted(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
    return unescape_lua_quoted(text:sub(2, -2))
  end
  if text:sub(1, 1) == "[" then
    local long = strip_long_bracket(text)
    if long then
      return long
    end
  end
  return text
end
