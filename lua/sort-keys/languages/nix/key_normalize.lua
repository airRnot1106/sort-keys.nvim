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
return function(text)
  if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    return unescape_nix_quoted(text:sub(2, -2))
  end
  -- Bare identifiers and dotted attrpaths (with or without quoted segments)
  -- round-trip verbatim — v1 keeps the dots inside the sort_key.
  return text
end
