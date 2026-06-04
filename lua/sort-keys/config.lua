-- Public configuration surface. setup() is idempotent: each call replaces the
-- user-handler map wholesale and never mutates built-ins.

local registry = require("sort-keys.registry")

local M = {}

-- Key normalization is an always-on parse-stage helper in the architecture, so
-- there is no normalize toggle here; `comparator` is the ORDER-axis base swap.
local DEFAULTS = {
  comparator = nil,
  handlers = {},
}

M.options = vim.deepcopy(DEFAULTS)

---Idempotent: each call rebuilds from defaults, so options and the user-handler
---map are replaced wholesale rather than accumulated across calls.
---@param opts table?
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts)
  registry.set_user_handlers(opts.handlers or {})
end

return M
