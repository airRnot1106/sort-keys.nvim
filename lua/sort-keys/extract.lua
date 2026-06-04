-- The parse-stage dispatcher: turn a buffer into an IR using the right
-- extractor for the language. A pack may ship a custom extractor for an
-- irregular AST (pack.extractor); otherwise the generic, query-driven
-- extractor handles it. Choosing between them is a parse-layer concern, so
-- command never needs to know a pack has a custom extractor — it just calls
-- extract.extract.

local generic = require("sort-keys.generic_extractor")

local M = {}

---@param bufnr integer
---@param target table
---@param pack table    -- may carry pack.extractor (a custom extractor module)
---@param deep boolean
---@return table|nil outline
function M.extract(bufnr, target, pack, deep)
  local extractor = pack.extractor or generic
  return extractor.extract(bufnr, target, pack, deep)
end

return M
