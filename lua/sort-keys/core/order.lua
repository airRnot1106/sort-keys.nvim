-- ORDER axis of the Sort abstraction: turn an order spec into a pure 3-way
-- comparator over entries. A flag is one transform layered on top of the base
-- key derivation; adding a `:sort`-compat flag means adding one branch here,
-- never touching placement / traverse / render.
--
-- The comparator returns -1 / 0 / 1 (not a bool) so the placement layer can
-- break ties by source order and keep the sort stable.
--
--   spec = {
--     reverse     = bool,    -- `!`      flip the result
--     ignore_case = bool,    -- `i`      compare case-insensitively
--     numeric     = bool,    -- `n`      compare by the first number in the key
--     pattern     = string?, -- `r/pat/` compare by the first Lua match of pat
--   }

local M = {}

---Derive the comparison value for a key under the spec's transforms.
---@param sort_key string
---@param spec table
---@return string|number
function M.key_of(sort_key, spec)
  local k = sort_key
  if spec.pattern then
    k = k:match(spec.pattern) or ""
  end
  if spec.numeric then
    -- `:sort n` orders by the first decimal number on the line; lines without
    -- one collate as 0, matching Vim's behavior.
    return tonumber((k:match("-?%d+%.?%d*"))) or 0
  end
  if spec.ignore_case then
    k = k:lower()
  end
  return k
end

---Whether `pattern` is a non-empty, well-formed Lua pattern. Used to reject a
---bad `:SortKeys /pat/` before it reaches the per-comparison string.match.
---@param pattern string?
---@return boolean
function M.valid_pattern(pattern)
  if not pattern or pattern == "" then
    return false
  end
  return (pcall(string.match, "", pattern))
end

---Build a 3-way comparator from an order spec. `spec.comparator` (per the
---ORDER axis of the architecture: "custom comparator injects here — swap the
---base") replaces the default key comparison; it is `fun(a, b, ctx) ->
---boolean|nil` returning whether a sorts before b, or nil to fall back to the
---default. Flags wrap the base: `reverse` still flips the final result.
---@param spec table?
---@return fun(a: table, b: table): integer
function M.build(spec)
  spec = spec or {}
  -- A malformed pattern (a stray "(" or a trailing "%") would otherwise raise
  -- "malformed pattern" on the first comparison and crash :SortKeys; drop it so
  -- the sort degrades to comparing the full key.
  local effective = {
    reverse = spec.reverse,
    ignore_case = spec.ignore_case,
    numeric = spec.numeric,
    pattern = M.valid_pattern(spec.pattern) and spec.pattern or nil,
  }
  local comparator = spec.comparator
  local ctx = {}

  local function default_3way(a, b)
    local ka = M.key_of(a.sort_key, effective)
    local kb = M.key_of(b.sort_key, effective)
    return (ka < kb and -1) or (ka > kb and 1) or 0
  end

  return function(a, b)
    local c
    if comparator then
      local ab = comparator(a, b, ctx)
      if ab ~= nil then
        -- Two probes give a stable 3-way (and an equality case) from a
        -- boolean "a before b" comparator.
        c = ab and -1 or (comparator(b, a, ctx) and 1 or 0)
      end
    end
    if c == nil then
      c = default_3way(a, b)
    end
    if effective.reverse then
      c = -c
    end
    return c
  end
end

return M
