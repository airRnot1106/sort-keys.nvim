local escapes = require("sort-keys.core.key_escapes")

-- Python regular-string escapes. v1 covers the byte-level set + `\u` / `\U`
-- (BMP + astral) + `\xNN`; octal `\NNN` and named `\N{...}` escapes are
-- intentionally skipped because they are not seen in practice as dict keys
-- and would round-trip stably as verbatim text anyway. `\v` / `\a` / `\0`
-- are present even though most JSON-derived dialects forbid them, because
-- Python admits them as ordinary escape sequences.
local PYTHON_SIMPLE_ESCAPES = {
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
  ["0"] = "\0",
}

local function read_hex(body, start, count)
  local hex = body:sub(start, start + count - 1)
  if #hex ~= count then
    return nil
  end
  return tonumber(hex, 16)
end

local function unescape_python(body)
  local out = {}
  local i = 1
  local n = #body
  while i <= n do
    local c = body:sub(i, i)
    if c == "\\" and i + 1 <= n then
      local nxt = body:sub(i + 1, i + 1)
      local simple = PYTHON_SIMPLE_ESCAPES[nxt]
      if simple then
        out[#out + 1] = simple
        i = i + 2
      elseif nxt == "x" then
        local cp = read_hex(body, i + 2, 2)
        if cp then
          out[#out + 1] = escapes.utf8_encode(cp)
          i = i + 4
        else
          -- Malformed: keep verbatim so the sort_key still round-trips.
          out[#out + 1] = c
          out[#out + 1] = nxt
          i = i + 2
        end
      elseif nxt == "u" then
        local cp = read_hex(body, i + 2, 4)
        if cp then
          out[#out + 1] = escapes.utf8_encode(cp)
          i = i + 6
        else
          out[#out + 1] = c
          out[#out + 1] = nxt
          i = i + 2
        end
      elseif nxt == "U" then
        local cp = read_hex(body, i + 2, 8)
        if cp then
          out[#out + 1] = escapes.utf8_encode(cp)
          i = i + 10
        else
          out[#out + 1] = c
          out[#out + 1] = nxt
          i = i + 2
        end
      else
        -- Python keeps an unrecognized escape sequence as the literal two
        -- characters (with a DeprecationWarning); preserving them here keeps
        -- the sort_key faithful to the source spelling.
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

-- A Python string literal prefix is up to two letters from {r,R,b,B,u,U,f,F}.
-- Valid combinations are rb/br/rf/fr (and case variants); v1 accepts any
-- two-char sequence from that set because the lexer would have rejected an
-- invalid combo upstream, and being lenient lets the normalizer still produce
-- a useful sort_key if the text was hand-passed.
local function is_python_prefix_char(c)
  return c == "r"
    or c == "R"
    or c == "b"
    or c == "B"
    or c == "u"
    or c == "U"
    or c == "f"
    or c == "F"
end

local function split_python_prefix(text)
  local p1 = text:sub(1, 1)
  if not is_python_prefix_char(p1) then
    return "", text
  end
  local p2 = text:sub(2, 2)
  if is_python_prefix_char(p2) then
    return text:sub(1, 2):lower(), text:sub(3)
  end
  return p1:lower(), text:sub(2)
end

local function strip_python_quotes(s)
  if #s >= 6 then
    local triple = s:sub(1, 3)
    if (triple == '"""' or triple == "'''") and s:sub(-3) == triple then
      return s:sub(4, -4)
    end
  end
  if #s >= 2 then
    local q = s:sub(1, 1)
    if (q == '"' or q == "'") and s:sub(-1) == q then
      return s:sub(2, -2)
    end
  end
  return nil
end

-- Python keys reach this layer in many surface forms: bare identifier / int /
-- bool / None (returned verbatim), and string literals carrying any of the
-- prefix combinations r / R / b / B / u / U / f / F (and rb / br / fr / rf).
-- Triple-quoted (`"""..."""`, `'''...'''`) is also legal. Raw strings — those
-- whose prefix contains an 'r' — disable escape processing entirely.
---@param text string  -- raw node text from a Python dict key, set/list element, etc.
---@return string
return function(text)
  local trimmed = text:match("^%s*(.-)%s*$") or text
  local prefix, rest = split_python_prefix(trimmed)
  local body = strip_python_quotes(rest)
  if not body then
    -- Not a string literal (bare identifier, integer, True/False/None, …).
    return trimmed
  end
  if prefix:find("r", 1, true) then
    return body
  end
  return unescape_python(body)
end
