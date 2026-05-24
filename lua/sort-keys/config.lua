local M = {}

M.defaults = {
  normalize_keys = true,
  comparator = nil,
  -- Map of config_name → handler spec for user-defined handlers (registered
  -- via setup). See `registry.set_user_handlers` for the spec shape.
  handlers = {},
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  -- Lazy require to keep registry independent of config at module load
  -- time. Calling at setup() is fine — by that point all modules are loaded.
  require("sort-keys.core.registry").set_user_handlers(M.options.handlers)
end

return M
