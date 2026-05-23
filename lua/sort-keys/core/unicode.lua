-- Identity stub: the NFC implementation strategy is not yet decided, so for
-- now ASCII and already-composed UTF-8 pass through unchanged. Decomposed
-- input is NOT normalized — callers depending on this must not assume it.

local M = {}

---@param s string
---@return string
function M.nfc(s)
  return s
end

return M
