-- Shared between JSON and JSONC handlers so that both produce identical
-- sort_key bytes for the same logical key; keeping this in one place
-- prevents the two from drifting on escape-decoding edge cases.

local M = {}

local SIMPLE_ESCAPES = {
  ['"'] = '"',
  ["\\"] = "\\",
  ["/"] = "/",
  b = "\b",
  f = "\f",
  n = "\n",
  r = "\r",
  t = "\t",
}

---@param cp integer
---@return string
local function utf8_encode(cp)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
  elseif cp < 0x10000 then
    return string.char(
      0xE0 + math.floor(cp / 0x1000),
      0x80 + math.floor(cp / 0x40) % 0x40,
      0x80 + cp % 0x40
    )
  else
    return string.char(
      0xF0 + math.floor(cp / 0x40000),
      0x80 + math.floor(cp / 0x1000) % 0x40,
      0x80 + math.floor(cp / 0x40) % 0x40,
      0x80 + cp % 0x40
    )
  end
end

local function read_hex4(body, start)
  local hex = body:sub(start, start + 3)
  if #hex ~= 4 then
    error("key_normalize.json: truncated \\u escape: " .. body)
  end
  local n = tonumber(hex, 16)
  if not n then
    error("key_normalize.json: invalid \\u escape: " .. body)
  end
  return n
end

local function decode_unicode_escape(body, i)
  local cp1 = read_hex4(body, i + 2)
  if cp1 >= 0xD800 and cp1 <= 0xDBFF then
    if body:sub(i + 6, i + 7) ~= "\\u" then
      error("key_normalize.json: lone high surrogate: " .. body)
    end
    local cp2 = read_hex4(body, i + 8)
    if cp2 < 0xDC00 or cp2 > 0xDFFF then
      error("key_normalize.json: invalid surrogate pair: " .. body)
    end
    local combined = 0x10000 + (cp1 - 0xD800) * 0x400 + (cp2 - 0xDC00)
    return utf8_encode(combined), 12
  end
  return utf8_encode(cp1), 6
end

local function unescape_json(body)
  local out = {}
  local i = 1
  local n = #body
  while i <= n do
    local c = body:sub(i, i)
    if c == "\\" and i + 1 <= n then
      local nxt = body:sub(i + 1, i + 1)
      local simple = SIMPLE_ESCAPES[nxt]
      if simple then
        out[#out + 1] = simple
        i = i + 2
      elseif nxt == "u" then
        local decoded, consumed = decode_unicode_escape(body, i)
        out[#out + 1] = decoded
        i = i + consumed
      else
        error("key_normalize.json: invalid escape \\" .. nxt)
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

local function strip_double_quotes(s)
  if #s >= 2 and s:sub(1, 1) == '"' and s:sub(-1) == '"' then
    return s:sub(2, -2)
  end
  return s
end

---@param text string  -- raw node text; may be quoted or an already-stripped string_content
---@return string
function M.json(text)
  return unescape_json(strip_double_quotes(text))
end

local function unescape_single_quoted(body)
  -- The only escape inside YAML single-quoted scalars is `''` for a literal
  -- `'`. Everything else is taken verbatim, so a simple gsub suffices.
  return (body:gsub("''", "'"))
end

---@param text string  -- raw node text; bare, single-quoted, or double-quoted YAML scalar
---@return string
function M.yaml(text)
  local trimmed = text:match("^%s*(.-)%s*$") or text
  if #trimmed >= 2 and trimmed:sub(1, 1) == '"' and trimmed:sub(-1) == '"' then
    return unescape_json(trimmed:sub(2, -2))
  end
  if #trimmed >= 2 and trimmed:sub(1, 1) == "'" and trimmed:sub(-1) == "'" then
    return unescape_single_quoted(trimmed:sub(2, -2))
  end
  return trimmed
end

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
function M.js(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return unescape_json(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
    return unescape_js_single_quoted(text:sub(2, -2))
  end
  return text
end

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
function M.lua(text)
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

-- TOML keys have three surface forms (TOML 1.0):
--   bare_key       — `foo`, `bar-1`, `_baz`
--   basic string   — `"foo"`, with JSON-style escapes (`\n`, `\"`, `\uXXXX`)
--   literal string — `'foo'`, no escape processing at all
-- Dotted keys (`a.b.c`) appear as one `dotted_key` node whose text contains
-- the dots and any quoted segments; v1 returns that text verbatim so the
-- whole dotted path becomes a single flat sort_key (per-segment normalization
-- + nested-table expansion is out of scope for v1).
function M.toml(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return unescape_json(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
    return text:sub(2, -2)
  end
  return text
end

return M
