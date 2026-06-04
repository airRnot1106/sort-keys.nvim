-- Escape-decoding primitives shared by the per-language key normalizers.
-- Several languages (JSON, YAML double-quoted, JS double-quoted, TOML basic,
-- Go interpreted, Elixir) share the JSON backslash + `\uXXXX` escape set, and
-- a few more (KDL, Python) need the UTF-8 encoder for their own `\u{...}` /
-- `\xNN` forms. Keeping these in one place prevents the languages from
-- drifting on escape-decoding edge cases.

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

---@param body string
---@return string
function M.unescape_json(body)
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

-- JS string escapes are a superset of JSON's: the simple set adds `\'`, `\v`,
-- `\0`, plus `\xNN` byte escapes and `\u{...}` code-point escapes, and — unlike
-- JSON — an *unrecognized* escape (`\s`, `\q`, ...) is legal and denotes the
-- bare character. A strict JSON decoder errors on all of these, which would
-- crash sorting on perfectly valid JS source, so JS keys decode through here.
local JS_SIMPLE_ESCAPES = {
  ["'"] = "'",
  ['"'] = '"',
  ["\\"] = "\\",
  ["/"] = "/",
  b = "\b",
  f = "\f",
  n = "\n",
  r = "\r",
  t = "\t",
  v = "\v",
  ["0"] = "\0",
}

---@param body string
---@return string
function M.unescape_js(body)
  local out = {}
  local i = 1
  local n = #body
  while i <= n do
    local c = body:sub(i, i)
    if c == "\\" and i + 1 <= n then
      local nxt = body:sub(i + 1, i + 1)
      local simple = JS_SIMPLE_ESCAPES[nxt]
      if simple then
        out[#out + 1] = simple
        i = i + 2
      elseif nxt == "u" and body:sub(i + 2, i + 2) == "{" then
        local close = body:find("}", i + 3, true)
        local cp = close and tonumber(body:sub(i + 3, close - 1), 16)
        if cp then
          out[#out + 1] = utf8_encode(cp)
          i = close + 1
        else
          -- malformed `\u{` — keep the `u` leniently rather than raising
          out[#out + 1] = nxt
          i = i + 2
        end
      elseif nxt == "u" then
        local decoded, consumed = decode_unicode_escape(body, i)
        out[#out + 1] = decoded
        i = i + consumed
      elseif nxt == "x" then
        local cp = tonumber(body:sub(i + 2, i + 3), 16)
        if cp then
          out[#out + 1] = utf8_encode(cp)
          i = i + 4
        else
          out[#out + 1] = nxt
          i = i + 2
        end
      else
        -- Unrecognized escape: JS drops the backslash and keeps the character.
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

---@param s string
---@return string
function M.strip_double_quotes(s)
  if #s >= 2 and s:sub(1, 1) == '"' and s:sub(-1) == '"' then
    return s:sub(2, -2)
  end
  return s
end

M.utf8_encode = utf8_encode

return M
