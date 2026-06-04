-- Intentionally a minimal subset reader: only `key = "string"` and
-- `key = true/false` pairs are supported. Table headers, arrays, dates, and
-- the rest of the TOML spec are out of scope and will raise on encounter.

local M = {}

local function parse_value(raw, lnum)
  -- String values may carry a trailing ` # comment`. Match up to the first
  -- closing quote, then require the remainder to be blank or a comment so a
  -- `#` between the quotes stays part of the value.
  if raw:sub(1, 1) == '"' then
    local content, rest = raw:match('^"(.-)"%s*(.*)$')
    if not content or (rest ~= "" and rest:sub(1, 1) ~= "#") then
      error(string.format("toml_loader.parse: unterminated string on line %d: %s", lnum, raw))
    end
    return content
  end
  -- Non-string scalars: strip an inline comment (TOML requires whitespace
  -- before `#`) before matching the keyword.
  local scalar = raw:gsub("%s+#.*$", "")
  if scalar == "true" then
    return true
  end
  if scalar == "false" then
    return false
  end
  error(string.format("toml_loader.parse: unsupported value on line %d: %s", lnum, raw))
end

---@param text string
---@return table<string, any>
function M.parse(text)
  local out = {}
  local lnum = 0
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lnum = lnum + 1
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
      local k, raw = trimmed:match("^([%w_]+)%s*=%s*(.+)$")
      if not k then
        error(string.format("toml_loader.parse: malformed line %d: %s", lnum, line))
      end
      out[k] = parse_value(raw, lnum)
    end
  end
  return out
end

---@param path string
---@return table<string, any>
function M.load(path)
  local f, err = io.open(path, "r")
  if not f then
    error(string.format("toml_loader.load: cannot open %s: %s", path, err or "unknown error"))
  end
  local text = f:read("*a")
  f:close()
  return M.parse(text)
end

return M
