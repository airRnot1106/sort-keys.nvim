local escapes = require("sort-keys.core.key_escapes")

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
        local encoded = cp and escapes.utf8_encode(cp)
        if encoded then
          out[#out + 1] = encoded
          i = close + 1
        else
          -- malformed or out-of-range `\u{...}`: keep verbatim, never raise
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

-- KDL node names and prop keys arrive as `identifier`s in three surface forms:
--   bare identifier — `config`, `foo-bar.baz` (no delimiters → verbatim)
--   escaped string  — `"bar baz"` with the JSON-ish escape set + `\u{...}`
--   raw string      — `r"..."`, `r#"..."#`, ... where escapes are inert
---@param text string  -- raw node text from a KDL node-name / prop-key identifier
---@return string
return function(text)
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
