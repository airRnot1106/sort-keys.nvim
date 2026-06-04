-- Public configuration surface. setup() is idempotent: each call replaces the
-- user-handler map wholesale and never mutates built-ins.

local registry = require("sort-keys.registry")

local M = {}

M.options = {
  normalize_keys = true,
  comparator = nil,
  handlers = {},
}

---@param opts table?
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", M.options, opts)
  registry.set_user_handlers(opts.handlers or {})
end

return M
