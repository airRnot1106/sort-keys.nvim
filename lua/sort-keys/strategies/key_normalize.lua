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

-- Nix basic-string keys use the JSON escape set plus `\$` (so a literal `$`
-- in a key text doesn't accidentally trigger anti-quotation `${...}`).
-- `${...}` interpolation inside a key is technically legal but extremely
-- rare in practice; v1 returns the raw text in that case rather than try
-- to evaluate the expression.
local NIX_ESCAPES = {
  ["\\"] = "\\",
  ['"'] = '"',
  ["$"] = "$",
  n = "\n",
  r = "\r",
  t = "\t",
}

local function unescape_nix_quoted(body)
  local out = {}
  local i = 1
  local n = #body
  while i <= n do
    local c = body:sub(i, i)
    if c == "\\" and i + 1 <= n then
      local nxt = body:sub(i + 1, i + 1)
      local simple = NIX_ESCAPES[nxt]
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

---@param text string  -- raw node text from a Nix attrpath / formal / inherited identifier
---@return string
function M.nix(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return unescape_nix_quoted(text:sub(2, -2))
  end
  -- Bare identifiers and dotted attrpaths (with or without quoted segments)
  -- round-trip verbatim — v1 keeps the dots inside the sort_key.
  return text
end

-- Pkl keys reach this layer in three surface forms:
--   bare identifier      — `name`, `attendants` (a property's identifier)
--   string-literal key   — `"a"` (the inner expr of a mapping entry `["a"]`)
--   backtick identifier  — `` `default` `` (Pkl escapes keyword identifiers)
-- v1 only strips the delimiters; Pkl's `\n` / `\u{...}` escape decoding is out
-- of scope and round-tripping the literal text keeps the sort_key stable with
-- the source spelling.
---@param text string  -- raw node text from a Pkl property identifier or mapping key
---@return string
function M.pkl(text)
  local t = text:match("^%s*(.-)%s*$") or text
  if #t >= 2 and t:sub(1, 1) == '"' and t:sub(-1) == '"' then
    return t:sub(2, -2)
  end
  if #t >= 2 and t:sub(1, 1) == "`" and t:sub(-1) == "`" then
    return t:sub(2, -2)
  end
  return t
end

-- KDL escaped-string escapes match the JSON set (`\\ \" \/ \b \f \n \r \t`)
-- except the unicode form is brace-delimited `\u{1-6 hex}` instead of JSON's
-- fixed-width `\uXXXX`. Anything else after a backslash is kept literally so a
-- malformed key still round-trips to a stable sort_key.
local KDL_SIMPLE_ESCAPES = {
  ["\\"] = "\\",
  ['"'] = '"',
  ["/"] = "/",
  b = "\b",
  f = "\f",
  n = "\n",
  r = "\r",
  t = "\t",
}

local function unescape_kdl(body)
  local out = {}
  local i = 1
  local n = #body
  while i <= n do
    local c = body:sub(i, i)
    if c == "\\" and i + 1 <= n then
      local nxt = body:sub(i + 1, i + 1)
      if nxt == "u" and body:sub(i + 2, i + 2) == "{" then
        local close = body:find("}", i + 3, true)
        local hex = close and body:sub(i + 3, close - 1) or nil
        local cp = hex and tonumber(hex, 16) or nil
        if cp then
          out[#out + 1] = utf8_encode(cp)
          i = close + 1
        else
          out[#out + 1] = c
          i = i + 1
        end
      else
        local simple = KDL_SIMPLE_ESCAPES[nxt]
        if simple then
          out[#out + 1] = simple
          i = i + 2
        else
          out[#out + 1] = c
          out[#out + 1] = nxt
          i = i + 2
        end
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

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
          out[#out + 1] = utf8_encode(cp)
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
          out[#out + 1] = utf8_encode(cp)
          i = i + 6
        else
          out[#out + 1] = c
          out[#out + 1] = nxt
          i = i + 2
        end
      elseif nxt == "U" then
        local cp = read_hex(body, i + 2, 8)
        if cp then
          out[#out + 1] = utf8_encode(cp)
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
function M.python(text)
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
function M.go(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return unescape_json(text:sub(2, -2))
  end
  if #text >= 2 and text:sub(1, 1) == "`" and text:sub(-1) == "`" then
    return text:sub(2, -2)
  end
  return text
end

-- Rust keys reach this layer as bare identifiers (struct field names,
-- shorthand initializers, use-list members). The only escape to undo is the
-- raw-identifier prefix `r#`, which Rust uses to allow keywords as identifier
-- names (e.g. `r#type`, `r#match`, `foo::r#type`). The prefix is stripped on
-- every component so the same logical path round-trips to a single sort_key
-- regardless of whether the source spells it `foo::r#bar` or `foo::bar`. The
-- character `#` is otherwise inadmissible inside a Rust identifier, so a
-- global gsub cannot collide with a legitimate sub-string.
---@param text string  -- raw node text from a Rust field / use-list identifier
---@return string
function M.rust(text)
  return (text:gsub("r#", ""))
end

-- KDL node names and prop keys arrive as `identifier`s in three surface forms:
--   bare identifier — `config`, `foo-bar.baz` (no delimiters → verbatim)
--   escaped string  — `"bar baz"` with the JSON-ish escape set + `\u{...}`
--   raw string      — `r"..."`, `r#"..."#`, ... where escapes are inert
---@param text string  -- raw node text from a KDL node-name / prop-key identifier
---@return string
function M.kdl(text)
  -- Raw string: `r`, N `#`, `"`, body, `"`, the same N `#`. The body is taken
  -- verbatim (escapes are not processed inside raw strings).
  local _, body = text:match('^r(#*)"(.*)"%1$')
  if body then
    return body
  end
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return unescape_kdl(text:sub(2, -2))
  end
  return text
end

return M
